local M = {}
local c = require "lsp-inlayhints.config"

M.setup = function(user_config)
  vim.validate { user_config = { user_config, "table", true } }
  c.load(user_config)
end

local inlay_hints = require "lsp-inlayhints.core"

-- {
--   config = <function 3>,
--   disable = <function 4>,
--   enable = <function 5>,
--   hide = <function 23>,
--   reset = <function 26>,
--   show = <function 30>,
-- }

-- M.disable = inlay_hints.disable
-- M.enable = inlay_hints.enable

-- Clear all hints in the current buffer
M.reset = inlay_hints.clear

M.toggle = inlay_hints.toggle

-- M.hide = inlay_hints.hide
M.show = inlay_hints.show
M.on_attach = inlay_hints.on_attach

return M
