local store = require("lsp-inlayhints.store")._store
local utils = require "lsp-inlayhints.utils"

local M = {}

M.servers_config = {
  default = {
    method = "textDocument/inlayHint",
  },
  jdtls = {
    hint_adapter = function(h)
      -- server doesn't specify 'InlayHintKind' and its settings pertain only to parameters.
      if not h.kind then
        h.kind = 2
      end
    end,
  },
}

function M.set_old_tsserver()
  M.servers_config["tsserver"] = {
    method = "typescript/inlayHints",
    result_adapter = function(result)
      return result.inlayHints or result
    end,
    hint_adapter = function(h)
      if h.text then
        h.label = h.text
      end
    end,
  }
end

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

  result = result_adapter(client.name, result) or {}
  return utils.tbl_map(hint_adapter(client.name), result)
end

return M
