# lsp-mason-tool-installer
> Auto-installs non-LSP Mason tools (formatters, linters, DAP adapters not handled elsewhere).

**Repo:** https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
**Local spec:** lua/plugins/lsp.lua:24
**Tags:** mason, formatters, linters, ensure_installed

## Scope

A thin wrapper around Mason that ensures a list of CLI tools is installed and (optionally) kept up to date. We use it for tools that aren't LSP servers (`mason-lspconfig` handles those) and aren't DAP adapters (`mason-nvim-dap` handles those) — typically formatters and linters consumed by `conform.nvim`.

## Install spec
```lua
{
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "mason-org/mason.nvim" },
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    ensure_installed = {
      "stylua",
      "prettierd",
      "prettier",
    },
    auto_update = false,
    run_on_start = true,
  },
}
```

## Common customizations
- `ensure_installed` *(string[], `{}`)* — Mason package names (CLIs, LSPs, anything).
- `auto_update` *(boolean, `false`)* — re-run installs every startup to fetch latest versions.
- `run_on_start` *(boolean, `true`)* — install on `VeryLazy`/plugin load.
- `start_delay` *(integer, `0`)* — ms before installer runs after startup.
- `debounce_hours` *(integer or nil, `nil`)* — skip auto-update if last run was within N hours.
- `integrations` *(table, `{ mason_lspconfig = true, mason_null_ls = true, mason_nvim_dap = true }`)* — let companion plugins manage their own packages.

(See https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim#configuration.)

## Our config

- `stylua` — Lua formatter (conform).
- `prettierd` / `prettier` — JS/TS/JSON/MD/CSS/YAML/HTML formatter (conform; daemon variant + fallback).
- `auto_update = false` — pin versions; manual `:MasonToolsUpdate` to refresh.
- `run_on_start = true` — install on first buffer load if missing.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| —   | —    | `:MasonToolsInstall` | Install all `ensure_installed` tools |
| —   | —    | `:MasonToolsUpdate` | Force-update installed tools |
| —   | —    | `:MasonToolsClean` | Remove tools no longer in `ensure_installed` |

## Links
- README: https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
- Related: [lsp-mason](lsp-mason.md), [format-conform](format-conform.md)

## Notes

DAP adapters (`php-debug-adapter`, `js-debug-adapter`, etc.) are installed by `mason-nvim-dap` in the debugger spec, not here.
