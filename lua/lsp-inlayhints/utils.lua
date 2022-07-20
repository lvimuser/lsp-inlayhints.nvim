local utils = {}

function utils.mk_handler(fn)
	return function(...)
		local config_or_client_id = select(4, ...)
		local is_new = type(config_or_client_id) ~= "number"
		if is_new then
			fn(...)
		else
			local err = select(1, ...)
			local method = select(2, ...)
			local result = select(3, ...)
			local client_id = select(4, ...)
			local bufnr = select(5, ...)
			local config = select(6, ...)
			fn(err, result, { method = method, client_id = client_id, bufnr = bufnr }, config)
		end
	end
end

function utils.request(bufnr, method, params, handler)
	return vim.lsp.buf_request(bufnr, method, params, utils.mk_handler(handler))
end

-- TODO: rewrite
-- Waits until duration has elapsed since the last call
utils.debounce = function(fn, duration)
	local timer = vim.loop.new_timer()
	local function inner(args)
		timer:stop()
		timer:start(
			duration,
			0,
			vim.schedule_wrap(function()
				fn(args)
			end)
		)
	end

	local group = vim.api.nvim_create_augroup("inlayhints__CleanupLuvTimers", {})
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
