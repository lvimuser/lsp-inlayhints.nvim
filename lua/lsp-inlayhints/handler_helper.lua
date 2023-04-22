local config = require "lsp-inlayhints.config"
local opts = config.options.inlay_hints

local get_type_vt = function(current_line, labels, line_hints)
  if not (opts.type_hints.show and next(labels)) then
    return ""
  end

  local pattern = opts.type_hints.separator .. "%s?$"
  local t = {}
  for i, label in ipairs(labels) do
    if opts.type_hints.remove_colon_start then
      -- remove ': ' or ':'
      label = label:match "^:?%s?(.*)$" or label
    end
    if opts.type_hints.remove_colon_end then
      label = label:match "(.*):$" or label
    end
    t[i] = label:gsub(pattern, "")
  end

  return (opts.type_hints.prefix or "") .. table.concat(t, opts.type_hints.separator)
end

local get_param_vt = function(labels)
  if not (opts.parameter_hints.show and next(labels)) then
    return ""
  end

  local t = {}
  for i, label in ipairs(labels) do
    if opts.parameter_hints.remove_colon_start then
      -- remove ': ' or ':'
      label = label:match "^:?%s?(.*)$" or label
    end
    if opts.parameter_hints.remove_colon_end then
      label = label:match "(.*):%s?$" or label
    end

    t[i] = label
  end

  return (opts.parameter_hints.prefix or "")
    .. "("
    .. table.concat(t, opts.parameter_hints.separator)
    .. ") "
end

local fill_labels = function(line_hints)
  local param_labels = {}
  local type_labels = {}

  for _, hint in ipairs(line_hints) do
    local tbl = hint.kind == 2 and param_labels or type_labels

    -- label may be a string or InlayHintLabelPart[]
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintLabelPart
    if type(hint.label) == "table" then
      local parts = {}
      for _, label_part in ipairs(hint.label) do
        parts[#parts + 1] = label_part.value
      end
      tbl[#tbl + 1] = table.concat(parts)
    else
      tbl[#tbl + 1] = hint.label
    end
  end

  return param_labels, type_labels
end

local current_line = function(bufnr, line)
  return vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
end

local function get_max_len(bufnr, parsed_data)
  local max_len = -1

  for line, _ in pairs(parsed_data) do
    local l = current_line(bufnr, line)
    if l then
      max_len = math.max(max_len, l:len())
    end
  end

  return max_len
end

local render_hints = function(bufnr, parsed, namespace, range)
  local max_len
  if opts.max_len_align then
    max_len = get_max_len(bufnr, parsed)
  end

  if opts.only_current_line then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    parsed = { [line] = parsed[line] }
  end

  for line, line_hints in pairs(parsed) do
    local param_labels, type_labels = fill_labels(line_hints)

    local param_vt = get_param_vt(param_labels)
    local type_vt = get_type_vt(nil, type_labels)

    local virt_text
    if type_vt ~= "" then
      if param_vt ~= "" then
        virt_text = type_vt .. opts.labels_separator .. param_vt
      else
        virt_text = type_vt
      end
    else
      virt_text = param_vt
    end

    local padding = ""
    if opts.max_len_align then
      padding = string.rep(
        " ",
        max_len - current_line(bufnr, line):len() + opts.max_len_align_padding
      )
    end

    if virt_text ~= "" then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
        virt_text = {
          { padding, "NONE" },
          { virt_text, opts.highlight },
        },
        hl_mode = "combine",
        priority = opts.priority,
      })
    end
  end
end

return {
  render_hints = render_hints,
}
