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
| `basedpyright` | `analysis.autoSearchPaths`, `useLibraryCodeForTypes`, `autoImportCompletions` all on. Under GAF: absolute `extraPaths` for the `~/freelancer-dev/api` monorepo from `gaf.lsp.basedpyright_extra_paths()`, `typeCheckingMode = "standard"`, `.git`-first priority `root_markers` (per-service `setup.py` would otherwise root one server per service), and `python.pythonPath` → `api311` pyenv venv when it exists — see [[gaf-lsp]]. |
| `ruff` | Hover provider disabled in `on_attach` so basedpyright owns hover. Ruff stays for lint, format, organize imports. |
| `phpantom_lsp` | `filetypes = { "php" }`, nested `root_markers = { { ".phpantom.toml" }, { ".git" }, { "composer.json" } }`. No `settings` — the server reads `.phpantom.toml` instead. Guarded on `executable()`: it comes from `brew install phpantom-lsp`, not mason. |
| `laravel_lsp` | The first-party `laravel/lsp`. `filetypes = { "php", "blade" }`, `root_markers = { "artisan" }` only, `pestGenerateDocBlocks = false`, and `phpEnvironment` resolved per root in `before_init`. Runs *alongside* `phpantom_lsp` — it answers framework strings, not PHP. Guarded on `executable()`; installed with `composer global require laravel/lsp`. See [[laravel-lsp]]. |
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

A post-config loop assigns a **distinct underline style per severity**, not just a distinct colour — four dim underlines are hard to tell apart by hue alone on a transparent background:

| Severity | Style |
|---|---|
| Error | `undercurl` |
| Warn | `underdouble` |
| Info | `underdotted` |
| Hint | `underdashed` |
| Ok | `underline` |

The theme's underline colour (`sp`) is preserved; only the style bits are replaced. Re-applied on
`ColorScheme`, since a colorscheme reload resets them to the theme's definitions. All four styles
require the tmux `Smulx`/`Setulc` overrides — see
[terminal-ghostty-tmux](terminal-ghostty-tmux.md). A terminal that doesn't understand the extended
SGR renders any of them as a plain underline, which is the same fallback the previous
undercurl→underline loop provided.

**Inlay hints** are enabled here with `vim.lsp.inlay_hint.enable(true)` — they ship with 0.12 but
stay off until asked for, and vtsls / basedpyright / rust-analyzer / dartls all produce them.
`LspInlayHint` is restyled (italic, no background) in [ui-moonfly](ui-moonfly.md); toggle per
buffer with `<leader>uh`.

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
| `<leader>uh` | n | `Snacks.toggle.inlay_hints()` | Toggle inlay hints (was `<leader>ci`) |
| `<leader>ux` | n | `Snacks.toggle.diagnostics()` | Toggle diagnostics (`<leader>ud*` is the duck group) |
| `[d` / `]d` | n | `vim.diagnostic.jump({ count = ±1 })` | Prev / next diagnostic |
| `[e` / `]e` | n | jump with `severity = ERROR` | Prev / next error |
| `[w` / `]w` | n | jump with `severity = WARN` | Prev / next warning |

## GAF integration

- Under `vim.g.gaf`, basedpyright is wired for the `~/freelancer-dev/api` monorepo: absolute `extraPaths` (repo root + 10 outer service dirs — the importable packages sit one level inside, often renamed: `rest/` → `api`, `users_midlayer/` → `users_mid`), `typeCheckingMode = "standard"`, `.git`-first `root_markers`, and `python.pythonPath` → the `api311` pyenv venv when present. Setup steps in [[gaf-lsp]].
- `<leader>cr` first routes CSS-class and tag contexts to `config/rename.lua` (see [[config-rename]]); the LSP fallback detects PHP buffers, advances the cursor past `$`, strips `$` from `cword`, then re-adds it to `newName` if the symbol is a variable. Built to dodge intelephense's broken `prepareProvider` range for `$var`. See [[ftplugin-php]].
- See [[gaf-lsp]] for the full GAF LSP integration layer.

## Links
- README: https://github.com/neovim/nvim-lspconfig
- Related: [lsp-mason-lspconfig](lsp-mason-lspconfig.md), [lsp-fidget](lsp-fidget.md), [lsp-actions-preview](lsp-actions-preview.md), [cmp-blink](cmp-blink.md), [ftplugin-php](ftplugin-php.md)

## Notes

Uses the modern `vim.lsp.config()` API rather than `require("lspconfig").server.setup{}`. The older `lspconfig` setup path is not invoked here — `mason-lspconfig` 2.x uses `vim.lsp.enable()` directly.
