local config = require "lsp-inlayhints.config"
local opts = config.options.inlay_hints

local fill_label = function(hint)
  local tbl = {}

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

  return tbl
end

local function may_render(label, line, col, range)
  if not label or label == "" then
    return false
  end
  return line >= range.start[1] and line <= range._end[1]
end

local M = {}

M.render_hints = function(bufnr, ns, hints, range, client_name)
  if opts.only_current_line then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    hints = vim.tbl_filter(function(h)
      return h.position.line == line
    end, hints)
  end

  for _, hint in pairs(hints) do
    local line, col = hint.position.line, hint.position.character

    local label = opts.label_formatter(fill_label(hint), hint.kind, opts, client_name)
    local virt_text = opts.virt_text_formatter(label, hint, opts, client_name)

    if virt_text and may_render(label, line, col, range) then
      -- TODO col value outside range
      pcall(function()
        vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
          virt_text = virt_text,
          virt_text_pos = "inline",
          strict = false,
          priority = opts.priority,
        })
      end)
    end
  end
end

return M
