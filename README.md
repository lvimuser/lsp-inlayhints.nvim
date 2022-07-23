# lsp-inlayhints.nvim

Originally based on simrat39's [rust-tools.nvim](https://github.com/simrat39/rust-tools.nvim) implementation.

## Installation

Add `lvimuser/lsp-inlayhints.nvim` using your favorite plugin manager and call
`require("lsp-inlayhints").setup()`. See [Configuration](#configuration).

You can lazy load it on `module` or `LspAttach` event if you're calling it
**after** nvim has attached the server.

### on_attach

```lua
require("lsp-inlayhints").on_attach(bufnr, client)
```

### LspAttach

For nvim0.8, you can use the `LspAttach` event:

```lua
local group = vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
vim.api.nvim_create_autocmd("LspAttach", {
  group = "LspAttach_inlayhints",
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    require("lsp-inlayhints").on_attach(args.buf, client)
  end,
})
```

### Configuration

Which `InlayHints` are provided depends on the language server you're using. Read their docs.

Highlight is set to `LspInlayHint`. If not set, defaults to `Comment` foreground with `CursorLine` background, creating a 'block'-like effect.

A common suggestion is to use `Comment`: `hi link LspInlayHint Comment`. VSCode's dark theme is similar to `hi LspInlayHint guifg=#d8d8d8 guibg=#3a3a3a`

```lua
local default_config = {
  inlay_hints = {
    parameter_hints = {
      show = true,
      prefix = "<- ",
      separator = ", ",
    },
    type_hints = {
      -- type and other hints
      show = true,
      prefix = "",
      separator = ", ",
      remove_colon_end = false,
      remove_colon_start = false,
    },
    -- separator between types and parameter hints. Note that type hints are
    -- shown before parameter
    labels_separator = "  ",
    -- whether to align to the length of the longest line in the file
    max_len_align = false,
    -- padding from the left if max_len_align is true
    max_len_align_padding = 1,
    -- whether to align to the extreme right or not
    right_align = false,
    -- padding from the right if right_align is true
    right_align_padding = 7,
    -- highlight group
    highlight = "LspInlayHint",
  },
  debug_mode = false,
}
```

## Available commands (wip):

### TODO enable

<!-- If previously attached, enables plugin and its autocommands for the current buffer if passed, or globally. -->

<!-- ```lua -->
<!-- ---@param bufnr | nil -->
<!-- require('lsp-inlayhints').enable(bufnr) -->
<!-- ``` -->

### TODO disable

Clear inlay hints and disable the plugin (globally).

### reset

Clears all inlay hints in the current buffer. Use this if it glitches out.

```lua
require('lsp-inlayhints').reset()
```

## Languages

Should work for all languages that implement the spec. Tested on `rust-analyzer (via rust-tools.nvim)`, `fsautocomplete (via ionide.vim)`, `sumneko_lua`.

### Rust

If you're using `rust-tools.nvim`, disable its inlay hints by setting `autoSetHints = false`.

### Typescript

While `tsserver` doesn't (strictly) implement the spec, there's a built-in workaround for it.

See <https://github.com/typescript-language-server/typescript-language-server#workspacedidchangeconfiguration> and <https://github.com/typescript-language-server/typescript-language-server/blob/master/README.md#inlay-hints-typescriptinlayhints-experimental> for the options.

### Clangd

Builtin support. See <https://clangd.llvm.org/extensions#inlay-hints>

### Other

If a server implements inlay hints on a different endpoint/method (not
`textDocument/inlayHints`), raise an issue with the request/response details to
check the possibility of a workaround.
