# ts-context
> Sticky header showing the enclosing function/class/scope at the top of the window.

**Repo:** https://github.com/nvim-treesitter/nvim-treesitter-context
**Local spec:** lua/plugins/treesitter.lua:60
**Tags:** treesitter, context, sticky-header, ui

## Scope
Pins the line(s) introducing the current scope (function, class, if-block, etc.) to the top of the window as you scroll into long bodies. Pure UI overlay — no keymaps in our config. Loads on first buffer read.

## Install spec
```lua
{
  "nvim-treesitter/nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    max_lines = 3,
  },
}
```

## Common customizations
- `enable` *(boolean, default `true`)* — toggle plugin.
- `multiwindow` *(boolean, default `false`)* — show context across multiple windows.
- `max_lines` *(number, default `0` = unlimited)* — max lines of context header.
- `min_window_height` *(number, default `0`)* — don't show context if window is shorter than this.
- `line_numbers` *(boolean, default `true`)* — render line numbers in the context window.
- `multiline_threshold` *(number, default `20`)* — max lines to show for a single context.
- `trim_scope` *(string, default `'outer'`)* — when truncating, trim `'inner'` or `'outer'` scopes first.
- `mode` *(string, default `'cursor'`)* — calculate context from `'cursor'` line or `'topline'`.
- `separator` *(string, default `nil`)* — single-character divider under the context (e.g. `'-'`).
- `zindex` *(number, default `20`)* — floating window z-index.
- `on_attach` *(function, default `nil`)* — return `false` to skip a buffer.

## Our config
- `max_lines = 3` — keeps the sticky header to at most 3 lines so it never dominates a tall function signature.
- Everything else left at defaults: `mode = 'cursor'`, `line_numbers = true`, `separator = nil`.

## Keymaps
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| — | — | — | None configured. `:TSContextToggle` is available via plugin commands. |

## Links
- README: https://github.com/nvim-treesitter/nvim-treesitter-context/blob/master/README.md
- Related: [ts-nvim-treesitter](ts-nvim-treesitter.md)

## Notes
- Useful commands provided by the plugin: `:TSContextToggle`, `:TSContextEnable`, `:TSContextDisable`.
- Highlight groups: `TreesitterContext`, `TreesitterContextLineNumber`, `TreesitterContextBottom` (overrideable via colorscheme).
