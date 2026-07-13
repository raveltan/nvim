# lsp-nvim-lspconfig
> Per-server `vim.lsp.config()` definitions for every LSP we use plus diagnostic UI tuning.

**Repo:** https://github.com/neovim/nvim-lspconfig
**Local spec:** lua/plugins/lsp.lua:42
**Tags:** lsp, config, capabilities, diagnostics, intelephense

## Scope

Registers configuration tables for each LSP server via the new `vim.lsp.config(name, opts)` API (Neovim 0.11+). `mason-lspconfig`'s `automatic_enable` then calls `vim.lsp.enable(name)` for each installed server, picking up these overrides. Also configures diagnostic signs, severity sort, and the float border.

## Install spec
```lua
{
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "saghen/blink.cmp" },
  config = function() ... end,
}
```

Loaded before `mason-lspconfig` fires `vim.lsp.enable()` — same `BufReadPre` event, but `mason-lspconfig` lists this as a dependency.

## Capabilities

`require("blink.cmp").get_lsp_capabilities()` is applied to every server so completion, snippet, and resolve features advertise correctly. See [cmp-blink](cmp-blink.md).

## Configured servers

| Server | Notes |
|--------|-------|
| `eslint` | `run = "onSave"`, `packageManager = "yarn"`. Sync disabled, 1000 ms debounce — large monorepos crash on rapid edits. |
| `basedpyright` | `analysis.autoSearchPaths`, `useLibraryCodeForTypes`, `autoImportCompletions` all on. Under GAF, `extraPaths = { "libgafthrift", "restutils" }` is appended from `gaf.lsp.basedpyright_extra_paths()`. |
| `ruff` | Hover provider disabled in `on_attach` so basedpyright owns hover. Ruff stays for lint, format, organize imports. |
| `intelephense` | `filetypes = { "php" }`, `root_markers = { "composer.json", ".git" }`, `files.maxSize = 5 MB`, excludes vendor/node_modules/storage/cache/coverage. `on_attach` disables `prepareProvider` for rename — see [[ftplugin-php]]. |
| `jsonls` | `schemas = require("schemastore").json.schemas()` + `validate.enable = true`. |
| `yamlls` | Built-in schemaStore disabled, replaced by `require("schemastore").yaml.schemas()`. |
| `tailwindcss` | Filetypes restricted to html/css/js/ts/jsx/tsx. `experimental.classRegex` matches `@apply` directives. Filtered out under GAF. |
| `html` | `autoClosingTags = false` — `nvim-ts-autotag` already inserts close tags. `embeddedLanguages.{css,javascript} = true`, formatter off. |
| `cssls` | Filetypes restricted to `css`, `scss`, `less`. |
| `typos_lsp` | `diagnosticSeverity = "Hint"` so it stays quiet. |

TypeScript is `vtsls`, configured here with the other servers (see [lsp-vtsls](lsp-vtsls.md)).

## Diagnostic UI

```lua
vim.diagnostic.config({
  virtual_text = false,            -- tiny-inline-diagnostic owns inline rendering
  signs = { text = { ERROR=" ", WARN=" ", INFO=" ", HINT=" " } },
  underline = { severity = { min = HINT } },
  update_in_insert = false,
  float = { border = "rounded" },
  jump = { float = true },
  severity_sort = true,
})
```

A post-config loop forces `underline = true` on `DiagnosticUnderline*` highlights when the terminal lacks undercurl support.

## Keymaps

Defined in `lua/config/keymaps.lua`, not in this spec. Neovim 0.11+ defaults (`grn`, `grr`, `gri`, `gra`, `gO`, `K`) are kept; the overrides below add formatting, rename, and diagnostic navigation.

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `K` | n | `vim.lsp.buf.hover` | Hover docs |
| `grn` | n | (default) `vim.lsp.buf.rename` | LSP rename (non-PHP) |
| `grr` | n | (default) `vim.lsp.buf.references` | References |
| `gri` | n | (default) `vim.lsp.buf.implementation` | Implementations |
| `gra` | n | (default) `vim.lsp.buf.code_action` | Code action (raw) |
| `gd` | n | (default `tagfunc`) | Goto definition |
| `gO` | n | (default) `vim.lsp.buf.document_symbol` | Document symbols |
| `<leader>ca` | n,v | `actions-preview.code_actions()` | Code action with diff preview |
| `<leader>cA` | n | `vim.lsp.buf.code_action({ context.only = "source" })` | Source action |
| `<leader>cr` | n | Smart rename: class → tag → LSP (PHP `$` sigil aware) | Rename class/tag/symbol |
| `<leader>cf` | n | `conform.format({ async = true })` | Format file |
| `<leader>cd` | n | `vim.diagnostic.open_float` | Line diagnostics |
| `<leader>ci` | n | toggle `vim.lsp.inlay_hint` | Toggle inlay hints |
| `<leader>ud` | n | toggle `vim.diagnostic` | Toggle diagnostics |
| `[d` / `]d` | n | `vim.diagnostic.jump({ count = ±1 })` | Prev / next diagnostic |
| `[e` / `]e` | n | jump with `severity = ERROR` | Prev / next error |
| `[w` / `]w` | n | jump with `severity = WARN` | Prev / next warning |

## GAF integration

- Under `vim.g.gaf`, `basedpyright.analysis.extraPaths` is extended with `libgafthrift` and `restutils` so cross-repo Python imports resolve.
- `<leader>cr` first routes CSS-class and tag contexts to `config/rename.lua` (see [[config-rename]]); the LSP fallback detects PHP buffers, advances the cursor past `$`, strips `$` from `cword`, then re-adds it to `newName` if the symbol is a variable. Built to dodge intelephense's broken `prepareProvider` range for `$var`. See [[ftplugin-php]].
- See [[gaf-lsp]] for the full GAF LSP integration layer.

## Links
- README: https://github.com/neovim/nvim-lspconfig
- Related: [lsp-mason-lspconfig](lsp-mason-lspconfig.md), [lsp-fidget](lsp-fidget.md), [lsp-actions-preview](lsp-actions-preview.md), [cmp-blink](cmp-blink.md), [ftplugin-php](ftplugin-php.md)

## Notes

Uses the modern `vim.lsp.config()` API rather than `require("lspconfig").server.setup{}`. The older `lspconfig` setup path is not invoked here — `mason-lspconfig` 2.x uses `vim.lsp.enable()` directly.
