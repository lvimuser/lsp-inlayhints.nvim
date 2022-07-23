-- TODO: same buffer opened  in two splits, but at different positions should render in both locations
-- https://github.com/simrat39/rust-tools.nvim
local M = {}
local utils = require "lsp-inlayhints.utils"
local config = require "lsp-inlayhints.config"
local adapter = require "lsp-inlayhints.adapter"
local store = require("lsp-inlayhints.store")._store

local AUGROUP = "_InlayHints"

--- Setup inlayHints
---@param bufnr number
---@param client table A |vim.lsp.client| object
---@param force boolean Whether to call the server regardless of capability
function M.on_attach(bufnr, client, force)
  if
    not (
      client.server_capabilities.inlayHintProvider
      or client.server_capabilities.clangdInlayHintsProvider
      or client.name == "tsserver"
      or force
    )
  then
    return
  end

  if store.b[bufnr].attached and store.b[bufnr].show and config.options.debug_mode then
    local msg = vim.inspect { "already attached", bufnr = bufnr, store = store.b[bufnr] }
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local debounce_ms = 300
  local timer, fn = utils.debounce(function()
    M.show(bufnr)
  end, debounce_ms)

  store.b[bufnr] = {
    client = { name = client.name, id = client.id },
    attached = true,
    show = fn,
    timer = timer,
  }

  if not store.active_clients[client.name] then
    store.b[bufnr].show()
  end
  store.active_clients[client.name] = true

  M.setup_autocmd(bufnr)
end

function M.setup_autocmd(bufnr)
  local events = { "BufEnter", "BufWritePost", "CursorHold", "InsertLeave" }

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = false })
  vim.api.nvim_create_autocmd(events, {
    group = group,
    buffer = bufnr,
    callback = function()
      if not store.b[bufnr].show then
        if config.options.debug_mode then
          local msg = string.format("[inlay_hints] 'show' nil for buffer %d. Store:\n%s",  bufnr, vim.inspect(store.b))
          vim.notify_once(msg, vim.log.levels.ERROR)
        end

        return
      end

      store.b[bufnr].show()
    end,
  })
end

--- Return visible range of the buffer (1-based lines, 1-based columns)
-- local function get_visible_range()
--   local _, line1, col1 = unpack(vim.fn.getpos "w0")
--   local _, line2, col2 = unpack(vim.fn.getpos "w$")

--   return { start = { line1, col1 }, _end = { line2, col2 } }
-- end

--- Return visible lines of the buffer (1-based indexing)
local function get_visible_lines()
  return { first = vim.fn.line "w0", last = vim.fn.line "w$" }
end

-- local function get_visible_range2(offset_encoding)
--   local line1, line2 = unpack(get_visible_lines())
--   local col1, col2 = col_of_row(line1, offset_encoding), col_of_row(line2, offset_encoding)

--   return { start = { line1, col1 }, _end = { line2, col2 } }
-- end

local function col_of_row(row, offset_encoding)
  row = row - 1

  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  if not line or #line == 0 then
    return 0
  end

  return vim.lsp.util._str_utfindex_enc(line, nil, offset_encoding)
end

--- Return visible range of the buffer
-- 'mark-indexed' (1-based lines, 0-based columns)
local function get_hint_ranges(offset_encoding)
  local line_count = vim.api.nvim_buf_line_count(0) -- 1-based indexing

  if line_count <= 200 then
    local col = col_of_row(line_count, offset_encoding)
    return {
      start = { 1, 0 },
      _end = { line_count, col },
    }
  end

  local extra = 30
  local visible = get_visible_lines()

  local start_line = math.max(1, visible.first - extra)
  local end_line = math.min(line_count, visible.last + extra)
  local end_col = col_of_row(end_line, offset_encoding)

  return {
    start = { start_line, 0 },
    _end = { end_line, end_col },
  }
end

local function make_params(start_pos, end_pos, bufnr)
  return {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      -- convert to 0-index
      start = { line = start_pos[1] - 1, character = start_pos[2] },
      ["end"] = { line = end_pos[1] - 1, character = end_pos[2] },
    },
  }
end

---@param bufnr number
---@param range table mark-like indexing (1-based lines, 0-based columns)
---Returns 0-indexed params (per LSP spec)
local function get_params(range, bufnr)
  return make_params(range.start, range._end, bufnr)
end

local namespace = vim.api.nvim_create_namespace "experimental/inlayHints"
local enabled = nil

local function parseHints(result, ctx)
  if type(result) ~= "table" then
    return {}
  end

  result = adapter.adapt(result, ctx)

  local map = {}
  for _, inlayHint in pairs(result) do
    if not (inlayHint.position and inlayHint.position.line) and config.options.debug_mode then
      -- This should not happen.
      vim.notify_once(
        "[inlay_hints] Failure to parse hint " .. vim.inspect(inlayHint),
        vim.log.levels.ERROR
      )
    end

    local line = tonumber(inlayHint.position.line)
    if not map[line] then
      ---@diagnostic disable-next-line: need-check-nil
      map[line] = {}
    end

    table.insert(map[line], {
      label = inlayHint.label,
      kind = inlayHint.kind or 1,
      range = inlayHint.position,
    })
  end

  return map
end

local function handler(err, result, ctx, range)
  if err and config.options.debug_mode then
    local msg = err.message or vim.inspect(err)
    vim.notify_once("[inlay_hints] LSP error:" .. msg, vim.log.levels.ERROR)
    return
  end

  local bufnr = ctx.bufnr
  if vim.api.nvim_get_current_buf() ~= bufnr then
    return
  end

  local parsed = parseHints(result, ctx)

  -- range given is 1-indexed, but clear is 0-indexed (end is exclusive).
  M.clear_inlay_hints(range.start[1] - 1, range._end[1])

  local helper = require "lsp-inlayhints.handler_helper"
  if helper.render_hints(bufnr, parsed, namespace) then
    enabled = true
  end
end

function M.toggle_inlay_hints()
  if enabled then
    M.clear_inlay_hints()
  else
    M.show()
  end
  enabled = not enabled
end

function M.disable_inlay_hints()
  -- clear augroup then namespace
  local group = vim.api.nvim_create_augroup(AUGROUP, {})
  pcall(vim.api.nvim_del_augroup_by_id, group)

  M.clear_inlay_hints()
end

--- Clear all hints in the current buffer
--- Lines are 0-indexed.
---@param line_start integer | nil, defaults to 0 (start of buffer)
---@param line_end integer | nil, defaults to -1 (end of buffer)
function M.clear_inlay_hints(line_start, line_end)
  -- clear namespace which clears the virtual text as well
  vim.api.nvim_buf_clear_namespace(0, namespace, line_start or 0, line_end or -1)
end

local function handler_with_range(range)
  return function(err, result, ctx)
    handler(err, result, ctx, range)
  end
end

-- Sends the request to get the inlay hints and show them
---@param bufnr number | nil
function M.show(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not store.b[bufnr].client then
    return
  end

  local client = vim.lsp.get_client_by_id(store.b[bufnr].client.id)
  local range = get_hint_ranges(client.offset_encoding)
  local params = get_params(range, bufnr)
  if not params then
    return
  end

  local method = adapter.method(bufnr)
  utils.request(client, bufnr, method, params, handler_with_range(range))
end

return M
