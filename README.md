# lsp-inlayhints.nvim

Originally based on simrat39's [rust-tools.nvim](https://github.com/simrat39/rust-tools.nvim)

## Installation

Add `"lvimuser/lsp-inlayhints.nvim"` using your favorite plugin manager. You
can lazy load on `module` or `LspAttach` event if you're calling it **after**
the nvim has attached the sever.

Then, on `on_attach` call:

```lua
if client.server_capabilities.inlayHintProvider then
  require("lsp-inlayhints").setup_autocmd(bufnr, client)
end
```

For nvim0.8, you can use the `LspAttach` autocmd:

```lua
local group = vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
vim.api.nvim_create_autocmd("LspAttach", {
  group = "LspAttach_inlayhints",
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client.server_capabilities.inlayHintProvider then
      require("lsp-inlayhints").setup_autocmd(args.buf, client)
    end
  end,
})
```

### Configuration

Which `InlayHints` are provided depends on the language server you're using. Read their docs.

Highlight is set to `LspInlayHint`. If not set, defaults to `Comment` foreground with `CursorLine` background, creating a 'block'-like effect.

A common suggestion is to use `Comment`: `hi link LspInlayHint Comment`. VSCode's dark theme is similar to `hi LspInlayHint guifg=#d8d8d8 guibg=#3a3a3a`

## Available commands (wip):

### enable

If previously attached, enables plugin and its autocommands for the current buffer if passed, or globally.

```lua
---@param bufnr | nil
require('lsp-inlayhints').enable(bufnr)
```

### disable/hide

If attached, disables the plugin and its autocmds for the current buffer ? or globally.

### enable/show

Calls both reset and disable

### reset

Clears namespace (calls 'hide') both reset then requests it again.

## Languages

Should work for all languages that implement the spec. Tested on `rust-analyzer (via rust-tools.nvim)`, `fsautocomplete (via ionide.vim)` and `sumneko_lua`.

### Typescript

While `tsserver` doesn't (strictly) implement the spec, there's a built-in workaround for it.

See <https://github.com/typescript-language-server/typescript-language-server#workspacedidchangeconfiguration> and <https://github.com/typescript-language-server/typescript-language-server/blob/master/README.md#inlay-hints-typescriptinlayhints-experimental> for the options.

### Other

If your server implements inlay hints on a different endpoint (not
`textDocument/inlayHints`), raise an issue with the request/response details to
check the possibility of a workaround.
