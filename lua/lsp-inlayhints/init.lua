local M = {}
local c = require "lsp-inlayhints.config"

M.setup = function(user_config)
  vim.validate { user_config = { user_config, "table", true } }
  c.load(user_config)
end

local inlay_hints = require "lsp-inlayhints.core"

M.on_attach = inlay_hints.on_attach
M.show = inlay_hints.show
M.toggle = inlay_hints.toggle

-- Clear all hints in the current buffer
M.reset = inlay_hints.clear

return M
