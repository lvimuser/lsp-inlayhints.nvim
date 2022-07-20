local has_hl, _ = pcall(vim.api.nvim_get_hl_by_name, "Comment")
local function createInlayHintHL()
  local hl = vim.api.nvim_get_hl_by_name("Comment", true)
  local foreground = string.format("#%x", hl["foreground"] or 0)
  if #foreground < 3 then
    foreground = ""
  end

  hl = vim.api.nvim_get_hl_by_name("CursorLine", true)
  local background = string.format("#%x", hl["background"] or 0)
  if #foreground < 3 then
    background = ""
  end

  vim.api.nvim_set_hl(0, "LspInlayHint", { fg = foreground, bg = background })
end

if not has_hl then
  createInlayHintHL()
end

local config = {}

local default_config = {
  tools = {
    inlay_hints = {
      only_current_line = false,
      only_current_line_autocmd = "CursorHold",
      show_parameter_hints = true,
      show_variable_name = false,
      parameter_hints_prefix = "<- ",
      type_hints_prefix = "",
      max_len_align = false,
      max_len_align_padding = 1,
      right_align = false,
      right_align_padding = 7,
      highlight = "LspInlayHint",
      debug_mode = false,
    },
  },
}

config.load = function(user_config)
  config.options = vim.tbl_deep_extend("force", default_config, user_config or {})
end

return config
