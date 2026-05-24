# gaf-lsp
> LSP server tweaks for the fl-gaf monorepo — basedpyright extra paths, tailwindcss disabled.

**Local file:** lua/gaf/lsp.lua
**Tags:** gaf freelancer lsp basedpyright tailwindcss mason intelephense

## Scope

Holds the GAF-specific LSP overrides applied from `lua/plugins/lsp.lua`. Currently two surfaces: (1) filters `tailwindcss` out of `mason-lspconfig` ensure_installed because the fl-gaf webapp doesn't use Tailwind, and (2) provides the `extraPaths` list used by `basedpyright` so Python type-resolution finds GAF's Thrift-generated libs and REST utility modules that live outside `PYTHONPATH`.

PHP intelephense settings (memory, stubs, large-file include limits) live in `lua/plugins/lsp.lua` itself, not here — this module is just the GAF deltas.

## How it loads

Required directly from `lua/plugins/lsp.lua` inside `if vim.g.gaf then ... end` blocks. No `setup()` — pure functions returning data.

```lua
-- In plugins/lsp.lua's mason-lspconfig config:
if vim.g.gaf then
  ensure_installed = require("gaf.lsp").filter_mason_servers(ensure_installed)
end

-- In the basedpyright vim.lsp.config block:
if vim.g.gaf then
  settings.basedpyright.analysis.extraPaths = require("gaf.lsp").basedpyright_extra_paths()
end
```

## Public API

- `M.filter_mason_servers(servers)` — removes `"tailwindcss"` from the input table. Returns a new filtered table (uses `vim.tbl_filter`).
- `M.basedpyright_extra_paths()` — returns `{ "libgafthrift", "restutils" }`. Relative to project root; basedpyright resolves them against the workspace folder.

## Keymaps / Commands

None — pure data helpers.

## Workflow examples

```lua
-- Disabling another server under GAF profile only:
function M.filter_mason_servers(servers)
  local drop = { tailwindcss = true, eslint = true }   -- example: also drop eslint
  return vim.tbl_filter(function(s) return not drop[s] end, servers)
end

-- Adding a third extra path:
function M.basedpyright_extra_paths()
  return { "libgafthrift", "restutils", "vendor/python/shared" }
end
```

## Links

- [gaf-overview](gaf-overview.md) — profile bootstrap
- [lsp-mason-lspconfig](lsp-mason-lspconfig.md) — ensure_installed wiring
- [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md) — basedpyright + intelephense config
- [ftplugin-php](ftplugin-php.md) — PHP buffer tricks (`$$` → `$this->`, native rename)

## Notes

- PHP buffers use **native** `vim.lsp.buf.rename`, not `inc-rename`, due to intelephense `$` sigil handling — see [ftplugin-php](ftplugin-php.md).
- Tailwind is filtered (not just disabled) so `mason-lspconfig` won't even download it on a fresh fl-gaf-only machine. Other configs (non-GAF) keep tailwindcss.
- `extraPaths` is **relative** to the basedpyright workspace root. If you launch nvim from outside the python project root, basedpyright resolves them against its detected workspace (usually fine).
- Add fl-gaf-only intelephense stubs / include paths the same way: extend this module + gate the application in `plugins/lsp.lua`.
