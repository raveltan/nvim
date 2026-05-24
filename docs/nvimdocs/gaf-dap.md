# gaf-dap
> GAF-specific PHP/xdebug DAP wiring — configuration + keymaps for Freelancer monorepo debugging.

**Module:** lua/gaf/dap.lua
**Loaded by:** lua/plugins/dap.lua:127, lua/plugins/dap.lua:143 (gated on `vim.g.gaf`)
**Tags:** gaf php xdebug dap freelancer

## Scope
Internal module. Provides two entry points: `keys()` returns the GAF-specific DAP keymap extensions, `setup_php_configuration()` registers `dap.configurations.php` for listening on Xdebug port 9003 with a remote→local path mapping. Only invoked when `vim.g.gaf` is truthy (i.e. nvim launched with `GAF=1`).

## Install spec
Not a plugin — required from `plugins/dap.lua`:
```lua
if vim.g.gaf then
  vim.list_extend(keys, require("gaf.dap").keys())   -- in keys = function()
  require("gaf.dap").setup_php_configuration()       -- in config = function()
end
```

## Public API
- `M.keys()` — returns a lazy.nvim keymap-spec list with `<leader>dx`/`<leader>dX`/`<leader>dv`/`<leader>dD` (see Keymaps).
- `M.setup_php_configuration()` — assigns `dap.configurations.php = { { type="php", request="launch", name="Listen for Xdebug (:9003)", port=9003, pathMappings={[paths.remote_root]=paths.fl_gaf} } }`. Idempotent: safe to call multiple times.

## Our config
- Single PHP launch config (`"Listen for Xdebug (:9003)"`) — we listen, devbox initiates the connection via the port-forward set up by `bin/gaf-xdebug start`.
- `stopOnEntry = false` — we want to hit the breakpoint, not pause on every request.
- `log = false` — flip to `true` for xdebug protocol debug output.
- `pathMappings = { [paths.remote_root] = paths.fl_gaf }` — `paths.remote_root` is the devbox path (`/home/rtanjaya/...`), `paths.fl_gaf` is the local checkout. Without this, breakpoints can't be matched between devbox source and local buffer.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>dx` | n | `:GafXdebugStart` | Start xdebug port-forward |
| `<leader>dX` | n | `:GafXdebugStop` | Stop xdebug port-forward |
| `<leader>dv` | n | `:GafXdebugValidate` | Validate xdebug IDE setup |
| `<leader>dD` | n | `infra.toggle_debug_flag` | Toggle GAF test `--debug` flag |

## GAF integration
This module *is* the GAF integration layer for DAP. Loaded only when `vim.g.gaf` is set (gated by the `GAF=1` env var per the user's auto-memory). The xdebug commands themselves live in [gaf-xdebug](gaf-xdebug.md); this module only exposes the DAP-side keys and PHP config.

## Links
- Related: [gaf-xdebug](gaf-xdebug.md), [dap-nvim-dap](dap-nvim-dap.md)
- Devbox is hard-coded to `rtanjaya` in `lua/gaf/paths.lua`.

## Notes
- **Critical:** `setup_php_configuration()` is called directly in `config = function()` — NOT via a `FileType=php` autocmd with `once=true`. The previous autocmd approach silently failed when FileType had already fired before dap loaded, causing neotest-phpunit's dap strategy to crash with `dap: expected not empty table, got nil`. See the in-file comment at lua/gaf/dap.lua:16-20.
- `infra.toggle_debug_flag` comes from `gaf.test_infra` — toggles a global flag that test runners check to inject `--debug`/xdebug into PHPUnit invocations.
