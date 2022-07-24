local config = require "lsp-inlayhints.config"
local opts = config.options.inlay_hints

-- in_place
local get_type_vt = function(current_line, type_labels, line_hints)
  if not opts.type_hints.show or vim.tbl_isempty(type_labels) then
    return ""
  end

  local virt_text = opts.type_hints.prefix or ""
  local process_type_label_vt = function(label)
    -- TODO need to pass range
    -- if opts.show_variable_name and current_line then
    --   local char_start = label.range.start.character
    --   local char_end = label.range["end"].character
    --   local variable_name = string.sub(current_line, char_start + 1, char_end)

    --   virt_text = string.format("%s%s: %s", virt_text, variable_name, label)
    -- else
    if opts.type_hints.remove_colon_start then
      -- remove ': ' or ':'
      label = label:match "^:?%s?(.*)$" or label
    end
    if opts.type_hints.remove_colon_end then
      label = label:match "(.*):$" or label
    end
    virt_text = virt_text .. label
  end

  local pattern = opts.type_hints.separator .. "%s?$"
  for i, label in ipairs(type_labels) do
    process_type_label_vt(label)
    if i ~= #type_labels and not virt_text:match(pattern) then
      virt_text = virt_text .. opts.type_hints.separator
    end
  end

  return virt_text
end

-- in_place
local get_param_vt = function(labels)
  if not opts.parameter_hints.show or vim.tbl_isempty(labels) then
    return ""
  end

  -- parameter hints inside brackets with commas and a specified prefix
  local virt_text = (opts.parameter_hints.prefix or "") .. "("

  for i, label in ipairs(labels) do
    if opts.parameter_hints.remove_colon_start then
      -- remove ': ' or ':'
      label = label:match "^:?%s?(.*)$" or label
    end
    if opts.parameter_hints.remove_colon_end then
      label = label:match "(.*):$" or label
    end

    virt_text = virt_text .. label
    if i ~= #labels then
      virt_text = virt_text .. opts.parameter_hints.separator
    end
  end
  virt_text = virt_text .. ") "

  return virt_text
end

local fill_labels = function(line_hints)
  -- segregate parameter hints and other hints
  local param_labels = {}
  local type_labels = {}

  for _, hint in ipairs(line_hints) do
    local tbl = hint.kind == 2 and param_labels or type_labels

    -- label may be a string or InlayHintLabelPart[]
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintLabelPart
    if type(hint.label) == "table" then
      local values = vim.tbl_map(function(label_part)
        return label_part.value
      end, hint.label)
      vim.list_extend(tbl, values)
    else
      table.insert(tbl, hint.label)
    end
  end

  return param_labels, type_labels
end

local function get_max_len(bufnr, parsed_data)
  local max_len = -1

  for line, _ in pairs(parsed_data) do
    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    if current_line then
      local current_line_len = string.len(current_line)
      max_len = math.max(max_len, current_line_len)
    end
  end

  return max_len
end

local render_hints = function(bufnr, parsed, namespace)
  local max_len
  if config.options.inlay_hints.max_len_align then
    max_len = get_max_len(bufnr, parsed)
  end

  local has_hint

  for line, line_hints in pairs(parsed) do
    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

    local param_labels, type_labels = fill_labels(line_hints)

    local param_vt = get_param_vt(param_labels)
    local type_vt = get_type_vt(current_line, type_labels)

    local virt_text = type_vt
    if type_vt ~= "" and param_vt ~= "" then
      virt_text = virt_text .. opts.labels_separator
    end

    virt_text = virt_text .. param_vt

    if config.options.inlay_hints.right_align then
      virt_text = virt_text .. string.rep(" ", config.options.inlay_hints.right_align_padding)
    end

    if config.options.inlay_hints.max_len_align then
      virt_text = string.rep(
        " ",
        max_len - current_line:len() + config.options.inlay_hints.max_len_align_padding
      ) .. virt_text
    end

    -- TODO: Refactor this block/previous loop in two functions: get_vt and set_vt
    -- on show, call get_vt before clearing
    if virt_text ~= "" then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
        virt_text_pos = config.options.inlay_hints.right_align and "right_align" or "eol",
        virt_text = {
          { virt_text, config.options.inlay_hints.highlight },
        },
        hl_mode = "combine",
      })

      has_hint = true
    end
  end

  return has_hint
end

return {
  render_hints = render_hints,
}
