# lsp-mason-tool-installer
> Installs non-LSP Mason tools (formatters, linters) on demand via `:MasonToolsInstall`/`:MasonToolsUpdate`.

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
  cmd = { "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate", "MasonToolsUpdateSync", "MasonToolsClean" },
  opts = {
    ensure_installed = {
      "stylua",
      "prettierd",
      "prettier",
    },
    auto_update = false,
    run_on_start = false,
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
- `run_on_start = false` — don't probe the registry on load; install/update only when a `:MasonTools*` command runs.
- Lazy-loads on `cmd`, not `event`: with `run_on_start = false` the plugin does nothing on file open anyway, and its `setup()` pcall-probes `mason-nvim-dap.mappings.source` — lazy.nvim's require-autoloader turned that probe into loading the entire DAP stack (nvim-dap, dap-view, virtual-text, persistent-breakpoints, …) on every first `BufReadPre`. The mason-nvim-dap integration still works when `:MasonToolsUpdate` actually runs.

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
