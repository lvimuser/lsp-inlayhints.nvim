local utils = {}

-- Waits until duration has elapsed since the last call
utils.debounce = function(fn, duration)
  local timer = vim.loop.new_timer()
  local function inner(...)
    local argv = { ... }
    timer:start(
      duration,
      0,
      vim.schedule_wrap(function()
        fn(unpack(argv))
      end)
    )
  end

  local group = vim.api.nvim_create_augroup("InlayHints__CleanupLuvTimers", { clear = false })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    callback = function()
      if timer then
        if timer:has_ref() then
          timer:stop()
          if not timer:is_closing() then
            timer:close()
          end
        end
        timer = nil
      end
    end,
  })

  return timer, inner
end

utils.tbl_map = function(fn, t)
  local ret = {}
  for k, v in pairs(t) do
    ret[k] = fn(v)
  end
  return ret
end

return utils
