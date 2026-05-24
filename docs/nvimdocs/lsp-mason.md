# lsp-mason
> Package manager for LSP servers, DAP adapters, linters, and formatters.

**Repo:** https://github.com/mason-org/mason.nvim
**Local spec:** lua/plugins/lsp.lua:2-6
**Tags:** mason, lsp, install, registry

## Scope

Mason is a portable package manager that downloads and installs external tooling (language servers, debug adapters, linters, formatters) into Neovim's data directory. It does not auto-attach anything — `mason-lspconfig` and `mason-tool-installer` drive what gets installed; Mason itself just exposes the registry, install/update commands, and the `:Mason` UI.

## Install spec
```lua
{
  "mason-org/mason.nvim",
  cmd = "Mason",
  config = true,
}
```

Loaded lazily on `:Mason` because installs are driven by `mason-lspconfig` and `mason-tool-installer`, which pull Mason in as a dependency before any LSP buffer event.

## Common customizations
- `install_root_dir` *(string, `stdpath('data') .. '/mason'`)* — where packages are installed.
- `PATH` *(string, `"prepend"`)* — how Mason's `bin/` is merged into Neovim's `PATH`.
- `registries` *(table, `{ 'github:mason-org/mason-registry' }`)* — package source list.
- `ui.border` *(string, `"none"`)* — border for the `:Mason` window.
- `ui.icons.package_installed/pending/uninstalled` *(strings)* — UI icons.
- `max_concurrent_installers` *(integer, `4`)* — parallel installs.

(See https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt for the full option set.)

## Our config

- `config = true` — accept all defaults; no overrides.
- Lazy-loaded on the `:Mason` command. Packages are still installed eagerly by the dependent specs because they list Mason as a dependency.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| —   | —    | `:Mason` | Open the Mason UI (install / update / uninstall) |
| —   | —    | `:MasonUpdate` | Refresh the registry index |
| —   | —    | `:MasonLog` | View install logs |

## Links
- README: https://github.com/mason-org/mason.nvim
- Related: [lsp-mason-lspconfig](lsp-mason-lspconfig.md), [lsp-mason-tool-installer](lsp-mason-tool-installer.md)

## Notes

The `bin/` directory under `install_root_dir` is prepended to Neovim's `PATH`, so installed CLIs (e.g. `stylua`, `prettierd`) are picked up by `conform.nvim` and other tools without extra config.
