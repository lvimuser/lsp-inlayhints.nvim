# lsp-inlayhints.nvim

Partial implementation of [LSP](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/) inlay hint.

## Installation

Add `lvimuser/lsp-inlayhints.nvim` using your favorite plugin manager and call
`require("lsp-inlayhints").setup()`. See [Configuration](#configuration).

You can lazy load it on `module` or `LspAttach` event if you're calling it
**after** nvim has attached the server.

### on_attach

```lua
require("lsp-inlayhints").on_attach(client, bufnr)
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

    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    require("lsp-inlayhints").on_attach(client, bufnr)
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
    },
    type_hints = {
      show = true,
    },
    label_formatter = function(tbl, kind, opts, client_name)
      if kind == 2 and not opts.parameter_hints.show then
        return ""
      elseif not opts.type_hints.show then
        return ""
      end

      return table.concat(tbl, ", ")
    end,
    virt_text_formatter = function(label, hint, opts, client_name)
      if client_name == "sumneko_lua" or client_name == "lua_ls" then
        if hint.kind == 2 then
          hint.paddingLeft = false
        else
          hint.paddingRight = false
        end
      end

      local vt = {}
      vt[#vt + 1] = hint.paddingLeft and { " ", "None" } or nil
      vt[#vt + 1] = { label, opts.highlight }
      vt[#vt + 1] = hint.paddingRight and { " ", "None" } or nil

      return vt
    end,
    only_current_line = false,
    -- highlight group
    highlight = "LspInlayHint",
    -- virt_text priority
    priority = 0,
  },
  enabled_at_startup = true,
  debug_mode = false,
}
```

</details>

## Languages

Should work for **all** languages that implement the spec. Tested on `rust-analyzer (via rust-tools.nvim)`, `fsautocomplete (via ionide.vim)`, `sumneko_lua`/`lua_ls`, `gopls`, `tsserver`.

### Rust

If you're using `rust-tools.nvim`, set `inlay_hints.auto` to false.

<details>

```lua
require("rust-tools").setup({
    tools = {
        inlay_hints = {
            auto = false
        }
    }
})
```

</details>

### TypeScript

`tsserver` is spec compliant from [v1.1.0](https://github.com/typescript-language-server/typescript-language-server/releases/tag/v1.1.0) onwards. If you're using an older version, add
`require("lsp-inlayhints.adapter").set_old_tsserver()`.

See [typescript-language-server#workspacedidchangeconfiguration](https://github.com/typescript-language-server/typescript-language-server#workspacedidchangeconfiguration).

<details><summary>Example configuration to enable inlay hints in TypeScript and JavaScript, using lspconfig:</summary>

```lua
lspconfig.tsserver.setup({
  settings = {
    typescript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      }
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      }
    }
  }
})
```

You might want to set `VariableTypeHints` to `false` if it's too noisy.

</details>

### Clangd

If you're on a version earlier than 15.0.0, you must use an older commit.

See <https://clangd.llvm.org/extensions#inlay-hints> and <https://clangd.llvm.org/config#inlayhints>.
If using `p00f/clangd_extensions.nvim`, set `autoSetHints = false`.

### Golang

See <https://github.com/golang/tools/blob/master/gopls/doc/inlayHints.md>. If you're using `ray-x/go.nvim`, set `lsp_inlay_hints = { enable = false }`.

<details>
<summary>Example</summary>

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

</details>

### Java (jdtls)

Available settings: https://github.com/redhat-developer/vscode-java/blob/master/package.json#L892-L916.

- Server doesn't set `inlayHintProvider` [capability](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#serverCapabilities).
- Server doesn't specify [InlayHintKind](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintKind) and its options refer only to parameters.

Builtin workaround: attach regardless and treat unspecified hints as `Parameter`.

### Other

If a server implements inlay hints on a different endpoint/method (not
`textDocument/inlayHint`), raise an issue with the request/response details to
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
