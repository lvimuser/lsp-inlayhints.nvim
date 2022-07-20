local M = {}
local c = require("lsp-inlayhints.config")

M.setup = function(user_config)
	vim.validate({ user_config = { user_config, "table", true } })
	c.load(user_config)
end

local inlay_hints = require("lsp-inlayhints.core")

M.inlay_hints = inlay_hints.set_inlay_hints
M.setup_autocmd = inlay_hints.setup_autocmd

return M
