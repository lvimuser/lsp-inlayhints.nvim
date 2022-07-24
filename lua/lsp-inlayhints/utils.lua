local utils = {}

function utils.server_ready(client)
  return not not client.rpc.notify("$/window/progress", {})
end

function utils.request(client, bufnr, method, params, handler)
  -- TODO: cancellation ?
  -- if so, we should and save the ids and check for overlapping ranges
  -- for id, r in pairs(client.requests) do
  --   if r.method == method and r.bufnr == bufnr and r.type == "pending" then
  --     client.cancel_request(id)
  --   end
  -- end

  local success, id = client.request(method, params, handler, bufnr)
  return success, id
end

-- TODO: rewrite
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

return utils
