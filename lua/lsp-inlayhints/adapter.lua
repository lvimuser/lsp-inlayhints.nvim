local store = require("lsp-inlayhints.store")._store

local M = {}

M.servers_config = {
  default = {
    method = "textDocument/inlayHint",
  },
  clangd = {
    method = "clangd/inlayHints",
  },
  tsserver = {
    method = "typescript/inlayHints",
    result_adapter = function(result)
      return result.inlayHints or result
    end,
    hint_adapter = function(h)
      if h.text then
        h.label = h.text
      end
    end,
  },
}

local generic_hint_adapter = function(hint)
  -- offspec
  -- tsserver: 'Parameter'|'Type'|'Enum'
  -- clangd:   'parameter'|'type'
  local kind = hint.kind
  if type(kind) == "string" then
    hint.kind = (kind:lower():match "parameter" and 2) or 1
  end
end

--- In-place
---@param client string client name
local hint_adapter = function(client)
  return function(h)
    if not h then
      return
    end

    generic_hint_adapter(h)

    local s = M.servers_config[client]
    if s and s.hint_adapter then
      s.hint_adapter(h)
    end

    return h
  end
end

---
---@param client string client name
local result_adapter = function(client, result)
  local c = M.servers_config[client]
  if c and c.result_adapter then
    return c.result_adapter(result)
  end

  return result
end

local hint_adapters = {}
local get_or_set_hint_adapter = function(client)
  if not hint_adapters[client] then
    hint_adapters[client] = hint_adapter(client)
  end

  return hint_adapters[client]
end

M.method = function(bufnr)
  local client = store.b[bufnr].client.name
  local c = M.servers_config
  return c[client] and c[client].method or c.default.method
end

-- Adapt responses to the spec interface
function M.adapt(result, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return {}
  end

  result = result_adapter(client.name, result)

  return vim.tbl_map(get_or_set_hint_adapter(client.name), result) or {}
end

return M
