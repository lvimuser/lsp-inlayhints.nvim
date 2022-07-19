local M = {}

local inlay_hints = require("lsp-inlayhints.core")

M.inlay_hints = inlay_hints.set_inlay_hints
M.setup_autocmd = inlay_hints.setup_autocmd

return M
