-- Global store/state management.
local M = {}
local options = require("lsp-inlayhints.config").options

local cleanup_timer = function(timer)
  if timer then
    if timer:has_ref() then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
    end
    timer = nil
  end
end

M._store = {
  active_clients = {},
  b = setmetatable({}, {
    __index = function(t, bufnr)
      vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
          if options.debug_mode then
            local msg = "detached from " .. tostring(bufnr)
            vim.notify(msg, vim.log.levels.INFO)
          end

          cleanup_timer(t[bufnr].timer)
          rawset(t, bufnr, nil)
        end,
      })

      t[bufnr] = {}
      return t[bufnr]
    end,
  }),
}

return M
