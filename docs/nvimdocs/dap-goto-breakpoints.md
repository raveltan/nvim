# dap-goto-breakpoints
> `]b` / `[b` navigation between nvim-dap breakpoints in the current buffer or workspace.

**Repo:** https://github.com/ofirgall/goto-breakpoints.nvim
**Local spec:** lua/plugins/dap.lua:107-109
**Tags:** dap breakpoint navigation jump

## Scope
Tiny helper plugin: three functions for jumping between breakpoints. No setup, no opts.

## Install spec
```lua
{ "ofirgall/goto-breakpoints.nvim" }
```

## Public API
- `require("goto-breakpoints").next()` — jump to the next breakpoint (alphabetic by file, then line).
- `require("goto-breakpoints").prev()` — jump to the previous breakpoint.
- `require("goto-breakpoints").stopped()` — jump to the line where the DAP session is currently stopped.

No setup call needed.

## Our config
No options. We expose only `next`/`prev` via `]b` / `[b` — `stopped` isn't bound (use `<leader>du` to open dap-view + click the frame instead).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `]b` | n | `goto-breakpoints.next()` | Next breakpoint |
| `[b` | n | `goto-breakpoints.prev()` | Prev breakpoint |

## Links
- README: https://github.com/ofirgall/goto-breakpoints.nvim
- Related: [dap-persistent-breakpoints](dap-persistent-breakpoints.md), [dap-nvim-dap](dap-nvim-dap.md)

## Notes
- Iterates over `dap.list_breakpoints()` — order is whatever nvim-dap returns (file-major, line-minor).
- No wrap-around: at the last breakpoint, `next()` is a no-op (does not warp to first).
