-- Global store/state management.
local M = {}

M._store = {
  active_clients = {},
  b = setmetatable({}, {
    __index = function(t, bufnr)
      t[bufnr] = {}
      return rawget(t, bufnr)
    end,
  }),
}

return M
