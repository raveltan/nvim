# dap-nvim-dap-view
> Modern, single-window winbar UI for nvim-dap (scopes/watches/breakpoints/threads/repl/console).

**Repo:** https://github.com/igorlfs/nvim-dap-view
**Local spec:** lua/plugins/dap.lua:6
**Tags:** dap ui winbar scopes watches repl

## Scope
Replacement for nvim-dap-ui. Renders one bottom window with a winbar that toggles between sections. We wire dap listeners so it opens on `attach`/`launch` and closes on `event_terminated`/`event_exited`.

## Install spec
```lua
{
  "igorlfs/nvim-dap-view",
  opts = {
    winbar = {
      sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "console" },
      default_section = "scopes",
    },
    windows = { size = 12 },
  },
  config = function(_, opts)
    local dap, dv = require("dap"), require("dap-view")
    dv.setup(opts)
    dap.listeners.before.attach["dap-view-config"]           = function() dv.open() end
    dap.listeners.before.launch["dap-view-config"]           = function() dv.open() end
    dap.listeners.before.event_terminated["dap-view-config"] = function() dv.close() end
    dap.listeners.before.event_exited["dap-view-config"]     = function() dv.close() end
  end,
}
```

## Common customizations
- `winbar.sections` *(string[], default `{"watches","scopes","exceptions","breakpoints","threads","repl"}`)* — sections shown in winbar. Available: watches, scopes, exceptions, breakpoints, threads, repl, sessions, console.
- `winbar.default_section` *(string, default `"watches"`)* — section opened when the view first appears. Must be in `sections`.
- `winbar.show_keymap_hints` *(bool, default `true`)* — append keymap hints to section labels.
- `winbar.separators` *(string[2]?, default nil)* — left/right separator strings.
- `windows.size` *(number, default `0.25`)* — relative (fraction) or absolute (integer) window size.
- `windows.position` *(string, default `"below"`)* — `below`/`above`/`left`/`right`.
- `windows.terminal.size` *(number, default `0.5`)*, `windows.terminal.position` *(string, default `"left"`)*, `windows.terminal.hide` *(string[], default `{}`)* — integrated terminal layout.
- `switchbuf` *(string, default `"usetab,uselast"`)* — vim switchbuf-style flags for jumping to source.
- `auto_toggle` *(bool, default `false`)* — auto open/close with debug session (we implement this manually via listeners instead).
- `follow_tab` *(bool, default `false`)* — reopen view when switching tabs.

## Our config
- Added `console` to sections (not in upstream default) — useful for adapter stdout (e.g. uvicorn).
- `default_section = "scopes"` — we want local variables visible first, not watches.
- `windows.size = 12` — absolute 12 rows; tall enough for a typical scopes tree without dominating screen.
- Manual listener wiring instead of `auto_toggle = true` — gives us precise hook names (`dap-view-config`) so they can be overridden/removed.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>du` | n | `dap-view.toggle()` | Toggle DAP UI |
| `<leader>de` | n/v | `:DapViewWatch` | Watch expression |

## Links
- README: https://github.com/igorlfs/nvim-dap-view
- Docs: https://igorlfs.github.io/nvim-dap-view/
- Related: [dap-nvim-dap](dap-nvim-dap.md)

## Notes
- Listener keys must be unique across nvim-dap consumers — `"dap-view-config"` is our namespace.
- The view auto-closes on `event_exited`, *not* on `terminate()` alone — both listeners are needed.
