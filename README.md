# lsp-inlayhints.nvim

Partial implementation of [LSP](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/) inlay hint.

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

For >0.8, you can use the `LspAttach` event:

```lua
vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
vim.api.nvim_create_autocmd("LspAttach", {
  group = "LspAttach_inlayhints",
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local bufnr = vim.lsp.get_client_by_id(args.buf)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    require("lsp-inlayhints").on_attach(bufnr, client)
  end,
})
```

### Configuration

If and which `InlayHints` are provided depends on the language server's configuration. **Read their docs**.

#### Highlight

Highlight group is `LspInlayHint`; defaults to `Comment` foreground with `CursorLine` background, creating a 'block'-like effect.

A common suggestion is to use `Comment`, either by linking it (`hi link LspInlayHint Comment`) or setting it in the options.

VSCode's dark theme is similar to `hi LspInlayHint guifg=#d8d8d8 guibg=#3a3a3a`.

#### Default Configuration

You only need to pass the options you want to override.

<details>

```lua
local default_config = {
  inlay_hints = {
    parameter_hints = {
      show = true,
      prefix = "<- ",
      separator = ", ",
      remove_colon_start = false,
      remove_colon_end = true,
    },
    type_hints = {
      -- type and other hints
      show = true,
      prefix = "",
      separator = ", ",
      remove_colon_start = false,
      remove_colon_end = false,
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

</details>

## Languages

Should work for **all** languages that implement the spec. Tested on `rust-analyzer (via rust-tools.nvim)`, `fsautocomplete (via ionide.vim)`, `sumneko_lua`, `gopls`.

### Rust

If you're using `rust-tools.nvim`, set `autoSetHints = false`.

### Typescript

While `tsserver` doesn't (strictly) implement the spec, there's a built-in workaround for it.

See <https://github.com/typescript-language-server/typescript-language-server#workspacedidchangeconfiguration> and <https://github.com/typescript-language-server/typescript-language-server/blob/master/README.md#inlay-hints-typescriptinlayhints-experimental> for the options.

### Clangd

Builtin support. See <https://clangd.llvm.org/extensions#inlay-hints> and
<https://clangd.llvm.org/config#inlayhints>.
If using `p00f/clangd_extensions.nvim`, set `autoSetHints = false`.

### Golang

Implements the spec. Configuration: <https://github.com/golang/tools/blob/master/gopls/doc/inlayHints.md>. Example:

```json
"gopls": {
  "hints": {
    "assignVariableTypes": true,
    "compositeLiteralFields": true,
    "constantValues": true,
    "functionTypeParameters": true,
    "parameterNames": true,
    "rangeVariableTypes": true
  }
}
```

If you're using `ray-x/go.nvim`, set `lsp_inlay_hints = { enable = false }`.

### Other

If a server implements inlay hints on a different endpoint/method (not
`textDocument/inlayHints`), raise an issue with the request/response details to
check the possibility of a workaround.

## Available commands:

### toggle

Enable/disable the plugin globally.

```lua
require('lsp-inlayhints').toggle()
```

### reset

Clears all inlay hints in the current buffer.

```lua
require('lsp-inlayhints').reset()
```

## Known issues

InlayHints (extmarks) get pushed to the line below when commenting lines. See: https://github.com/lvimuser/lsp-inlayhints.nvim/issues/2#issuecomment-1197975664.

## Missing

- [Resolve request](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHint_resolve)
- Command|Execute|TextEdits. Ref: [inlayHintLabelPart](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintLabelPart)

## Acknowledgements

Originally based on simrat39's [rust-tools.nvim](https://github.com/simrat39/rust-tools.nvim) implementation.

References:

- nvim's builtin codelens
- VSCode
