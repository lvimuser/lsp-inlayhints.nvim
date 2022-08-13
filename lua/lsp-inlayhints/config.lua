local function setInlayHintHL()
  local has_hl, hl = pcall(vim.api.nvim_get_hl_by_name, "LspInlayHint", true)
  if has_hl and (hl["foreground"] or hl["background"]) then
    return
  end

  hl = vim.api.nvim_get_hl_by_name("Comment", true)
  local foreground = string.format("#%06x", hl["foreground"] or 0)
  if #foreground < 3 then
    foreground = ""
  end

  hl = vim.api.nvim_get_hl_by_name("CursorLine", true)
  local background = string.format("#%06x", hl["background"] or 0)
  if #foreground < 3 then
    background = ""
  end

  vim.api.nvim_set_hl(0, "LspInlayHint", { fg = foreground, bg = background })
end

local config = {
  options = {},
}

local default_config = {
  inlay_hints = {
    parameter_hints = {
      show = true,
      prefix = "<- ",
      separator = ", ",
      remove_colon_start = false,
      remove_colon_end = true,
    },
    -- type and other hints
    type_hints = {
      show = true,
      prefix = "",
      separator = ", ",
      remove_colon_start = false,
      remove_colon_end = false,
    },
    -- separator between types and parameter hints. Note that type hints are shown before parameter
    labels_separator = "  ",
    -- whether to align to the length of the longest line in the file
    max_len_align = false,
    -- padding from the left if max_len_align is true
    max_len_align_padding = 1,
    -- highlight group
    highlight = "LspInlayHint",
  },
  debug_mode = false,
}

config.load = function(user_config)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("_InlayHintsColorscheme", {}),
    pattern = "*",
    callback = setInlayHintHL,
  })

  setInlayHintHL()
  config.options = vim.tbl_deep_extend("force", default_config, user_config or {})
end

return config
