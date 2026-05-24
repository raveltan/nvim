# dap-persistent-breakpoints
> Persist nvim-dap breakpoints across nvim restarts (per-file JSON in stdpath/data).

**Repo:** https://github.com/Weissle/persistent-breakpoints.nvim
**Local spec:** lua/plugins/dap.lua:100-106
**Tags:** dap breakpoint persistence session

## Scope
Wraps nvim-dap's breakpoint API and serialises breakpoint state to `stdpath('data')/nvim_checkpoints/`. Reloads them when the matching buffer is opened. Use its `api` module instead of `dap.toggle_breakpoint()` so additions/removals are written through.

## Install spec
```lua
{
  "Weissle/persistent-breakpoints.nvim",
  opts = {
    load_breakpoints_event = { "BufReadPost" },
  },
}
```

## Common customizations
- `save_dir` *(string, default `stdpath('data')/nvim_checkpoints`)* — where the per-project JSON lives.
- `load_breakpoints_event` *(string|string[], default `nil`)* — autocmd event(s) that trigger reload. `"BufReadPost"` is the recommended value; without this, breakpoints are loaded only on demand.
- `perf_record` *(bool, default `false`)* — record timing data; inspect via `:lua require('persistent-breakpoints.api').print_perf_data()`.
- `on_load_breakpoint` *(function, default `nil`)* — callback after reload (e.g. to refresh the dap-view list).
- `always_reload` *(bool, default `false`)* — reload on every event fire (needed if you use session plugins that swap buffer contents).

## Our config
- `load_breakpoints_event = { "BufReadPost" }` — auto-reload on file open. Default `nil` means breakpoints sit on disk but never come back.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>db` | n | `api.toggle_breakpoint()` | Toggle breakpoint |
| `<leader>dB` | n | `api.set_conditional_breakpoint()` | Conditional breakpoint |
| `<leader>dC` | n | `api.clear_all_breakpoints()` | Clear all breakpoints |

(Defined in the top-level dap `keys = function()` block, not in this plugin's spec.)

## Links
- README: https://github.com/Weissle/persistent-breakpoints.nvim
- Related: [dap-nvim-dap](dap-nvim-dap.md), [dap-goto-breakpoints](dap-goto-breakpoints.md)

## Notes
- **Always** call `persistent-breakpoints.api.toggle_breakpoint()` rather than `dap.toggle_breakpoint()` — the latter bypasses serialisation.
- Storage key is the absolute file path; renames lose state.
- `api.set_log_point()` is available but not bound in our config.
