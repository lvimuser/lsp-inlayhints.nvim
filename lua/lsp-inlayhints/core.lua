local M = {}
local utils = require "lsp-inlayhints.utils"
local config = require "lsp-inlayhints.config"
local adapter = require "lsp-inlayhints.adapter"
local store = require("lsp-inlayhints.store")._store
local uv = vim.loop

local AUGROUP = "_InlayHints"
local ns = vim.api.nvim_create_namespace "textDocument/inlayHints"
local enabled

-- TODO Set client capability
vim.lsp.handlers["workspace/inlayHint/refresh"] = function(_, _, ctx)
  local buffers = vim.lsp.get_buffers_by_client_id(ctx.client_id)
  for _, bufnr in pairs(buffers) do
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end

  -- For each visible win/bufnr, call show().

  return vim.NIL
end

local debounced_fn
local function set_debounced_fn()
  if debounced_fn then
    return debounced_fn
  end

  local _, fn = utils.debounce(function(bufnr, mode)
    local delay = mode ~= "n" and 1250 or nil
    M.show(bufnr, delay)
  end, 50)

  debounced_fn = fn
end

local function first_request(bufnr, delay)
  store.b[bufnr].first_request = false
  -- give it some time for the server to start;
  M.show(bufnr, delay or 2000, true)
  store.b[bufnr].first_request = true
end

local function set_store(client, bufnr)
  if store.b[bufnr].attached then
    return
  end

  store.b[bufnr].client = { name = client.name, id = client.id }
  store.b[bufnr].attached = true

  -- give it some time for the server to start;
  first_request(bufnr)

  set_debounced_fn()

  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function()
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end,
    on_lines = function(_, _, _, first_lnum, last_lnum)
      if not store.b[bufnr].attached then
        rawset(store.b, bufnr, nil)
        return true
      end

      local mode = vim.api.nvim_get_mode().mode
      debounced_fn(bufnr, mode)
    end,
  })
end

--- Setup inlayHints
---@param bufnr number
---@param client table A |vim.lsp.client| object
---@param force? boolean Whether to call the server regardless of capability
function M.on_attach(client, bufnr, force)
  -- TODO Remove
  if type(bufnr) == "table" and type(client) == "number" then
    vim.notify_once(
      "[LSP Inlayhints] on_attach should be called with (client, bufnr)",
      vim.log.levels.WARN
    )

    ---@diagnostic disable-next-line: cast-local-type
    client, bufnr = bufnr, client
  end
  if not client then
    vim.notify_once("[LSP Inlayhints] Tried to attach to a nil client.", vim.log.levels.ERROR)
    return
  end

  if
    not (
      client.server_capabilities.inlayHintProvider
      or client.name == "tsserver"
      or client.name == "jdtls"
      or force
    )
  then
    return
  end

  enabled = config.options.enabled_at_startup

  if config.options.debug_mode then
    vim.notify_once("[LSP Inlayhints] attached to " .. client.name, vim.log.levels.TRACE)
  end

  set_store(client, bufnr)
  M.setup_autocmd(bufnr)
end

function M.setup_autocmd(bufnr)
  -- guard against multiple calls
  if store.b[bufnr].aucmd then
    return
  end
  store.b[bufnr].aucmd = true

  local aucmd = vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup(AUGROUP, { clear = false }),
    buffer = bufnr,
    callback = function()
      first_request(bufnr)
    end,
  })

  if vim.fn.has "nvim-0.8" > 0 then
    local group = vim.api.nvim_create_augroup(AUGROUP .. "Detach", { clear = false })
    -- Needs nightly!
    -- https://github.com/neovim/neovim/commit/2ffafc7aa91fb1d9a71fff12051e40961a7b7f69
    vim.api.nvim_create_autocmd("LspDetach", {
      group = group,
      buffer = bufnr,
      once = true,
      callback = function(args)
        if not store.b[bufnr] or args.data.client_id ~= store.b[bufnr].client_id then
          return
        end
        for _, v in pairs { aucmd } do
          pcall(vim.api.nvim_del_autocmd, v)
        end
        store.b[bufnr].attached = false
      end,
    })
  end
end

--- Return visible lines of the buffer (1-based indexing)
local function get_visible_lines()
  return { first = vim.fn.line "w0", last = vim.fn.line "w$" }
end

local function col_of_row(row, offset_encoding)
  row = row - 1

  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  if not line or #line == 0 then
    return 0
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return vim.lsp.util._str_utfindex_enc(line, nil, offset_encoding)
end

--- Return visible range of the buffer
-- 'mark-indexed' (1-based lines, 0-based columns)
local function get_hint_ranges(offset_encoding, full)
  local line_count = vim.api.nvim_buf_line_count(0) -- 1-based indexing

  if full or line_count <= 200 then
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

local function parseHints(result, ctx)
  if type(result) ~= "table" then
    return {}
  end

  result = adapter.adapt(result, ctx)

  local map = {}
  for _, inlayHint in pairs(result) do
    local line = tonumber(inlayHint.position.line)
    if not map[line] then
      ---@diagnostic disable-next-line: need-check-nil
      map[line] = {}
    end

    map[line][#map[line] + 1] = {
      label = inlayHint.label,
      kind = inlayHint.kind or 1,
      position = inlayHint.position,
    }

    table.sort(map[line], function(a, b)
      return a.position.character < b.position.character
    end)
  end

  return map
end

local function on_refresh(err, result, ctx, range)
  if err then
    M.clear(ctx.bufnr, range.start[1] - 1, range._end[1])

    if config.options.debug_mode then
      local msg = err.message or vim.inspect(err)
      vim.notify_once("[inlay_hints] LSP error:" .. msg, vim.log.levels.ERROR)
      return
    end
  end

  local bufnr = ctx.bufnr
  local parsed = parseHints(result, ctx)

  -- range given is 1-indexed, but clear is 0-indexed (end is exclusive).
  M.clear(bufnr, range.start[1] - 1, range._end[1])

  local helper = require "lsp-inlayhints.handler_helper"
  helper.render_hints(bufnr, parsed, ns, range)
end

function M.toggle()
  if enabled then
    enabled = false
    M.clear()
  else
    enabled = true
    M.show()
  end
end

--- Clear all hints in the specified buffer
--- Lines are 0-indexed.
---@param bufnr integer | nil, defaults to current buffer
---@param line_start integer | nil, defaults to 0 (start of buffer)
---@param line_end integer | nil, defaults to -1 (end of buffer)
function M.clear(bufnr, line_start, line_end)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- clear namespace which clears the virtual text as well
  vim.api.nvim_buf_clear_namespace(bufnr, ns, line_start or 0, line_end or -1)
end

local scheduler = require("lsp-inlayhints.utils").scheduler:new()
local cts = utils.cancellationTokenSource:new()

-- Sends the request to get the inlay hints and show them
---@param bufnr number | nil
---@param delay integer | nil additional delay in ms.
function M.show(bufnr, delay, full)
  -- TODO
  -- a change somewhere in the buffer might cause other hints to change, we should
  -- get range for all visible window/bufnr.
  if not enabled then
    return
  end

  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not store.b[bufnr].client or store.b[bufnr].first_request then
    return
  end

  cts:cancel()
  cts = utils.cancellationTokenSource:new()

  local info = require("lsp-inlayhints.FeatureDebounce").for_("InlayHints", { min = 25 })

  delay = math.max(info.get(bufnr), delay or 0)

  local token = cts.token
  scheduler:schedule(function()
    if token.isCancellationRequested then
      return
    end

    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end

    local client = vim.lsp.get_client_by_id(store.b[bufnr].client.id)
    if not client then
      return
    end

    local range = get_hint_ranges(client.offset_encoding, store.b[bufnr].first_request)
    local params = get_params(range, bufnr)
    if not params then
      return
    end

    utils.cancel_requests(client, store.b[bufnr].requests[client.id])
    store.b[bufnr].requests[client.id] = {}

    local t1 = uv.now()
    local success, id = client.request(adapter.method(bufnr), params, function(err, result, ctx)
      if store.b[bufnr].first_request then
        store.b[bufnr].first_request = false
        info.update(bufnr, 200)
      else
        uv.update_time()
        info.update(bufnr, (uv.now() - t1))
      end

      if token.isCancellationRequested then
        return
      end

      if config.options.debug_mode then
        local n = info.get(bufnr)
        if n > 250 then
          vim.notify(
            string.format("[LSP Inlayhints] Delay %d for buffer %d", n, bufnr),
            vim.log.levels.TRACE
          )
        end
      end

      on_refresh(err, result, ctx, range)
    end, bufnr)

    if success then
      table.insert(store.b[bufnr].requests[client.id], id)
    end
  end, delay)
end

return M
