# ui-mini-indentscope
> Animated indent-scope guide (vertical bar marking the current block); animation disabled for performance, large buffers and noisy filetypes opt out.

**Repo:** https://github.com/echasnovski/mini.indentscope
**Local spec:** lua/plugins/ui.lua:115-143
**Tags:** indent, ui, visual-guide

## Scope
Draws a vertical line (`│`) showing the indent scope around the cursor. Updates as the cursor moves. We disable the per-line animation (it caused quadratic redraws per cursor move) and skip the feature entirely on splash/explorer/diagnostic filetypes and on buffers exceeding 1500 lines.

## Install spec
```lua
{
  "echasnovski/mini.indentscope",
  event = { "BufReadPre", "BufNewFile" },
  opts = function() ... end,
  init = function() ... end,
}
```

## Common customizations
Passed to `require("mini.indentscope").setup(config)`:

- `symbol` *(string, `"╎"`)* — the glyph drawn for the scope indicator.
- `draw.delay` *(int ms, `100`)* — debounce before drawing after CursorMoved.
- `draw.animation` *(fn, gen_animation.none())* — step-duration function; return `0` to disable animation entirely.
- `draw.predicate` *(fn, `function(scope) return not scope.body.is_incomplete end`)* — gate whether to draw at all.
- `draw.priority` *(int, `2`)* — extmark priority.
- `mappings.object_scope` *(string, `"ii"`)* — inner-scope text object.
- `mappings.object_scope_with_border` *(string, `"ai"`)* — scope including borders.
- `mappings.goto_top` *(string, `"[i"`)* — jump to scope top.
- `mappings.goto_bottom` *(string, `"]i"`)* — jump to scope bottom.
- `options.border` *(string, `"both"`)* — which borders count: `"both"`, `"top"`, `"bottom"`, `"none"`.
- `options.indent_at_cursor` *(bool, `true`)* — reference indent uses cursor column.
- `options.n_lines` *(int, `10000`)* — max lines scanned per direction.
- `options.try_as_border` *(bool, `false`)* — when cursor is on a less-indented line, treat it as a border of the adjacent scope instead.

Per-buffer disable: `vim.b.miniindentscope_disable = true`.

## Our config
- `symbol = "│"` — solid vertical bar (heavier than upstream `╎`).
- `options.try_as_border = true` — improves UX on the closing line of a block.
- `draw.animation = function() return 0 end` — kills animation. The comment notes quadratic redraw per cursor move was a CPU sink.

`init` autocmds:
- `FileType` — sets `vim.b.miniindentscope_disable = true` on `help`, `alpha`, `dashboard`, `neo-tree`, `Trouble`, `trouble`, `lazy`, `mason`, `notify`, `toggleterm`, `lazyterm`, `snacks_dashboard`, `satellite`, `undotree`, `diff`, `dap-view`, `dap-view-term`, `dap-repl`.
- `BufReadPost` — disables on buffers with > 1500 lines.

## Keymaps
Defaults inherited (we don't override): `ii`/`ai` text objects, `[i`/`]i` jumps.

## Links
- README: https://github.com/echasnovski/mini.indentscope/blob/main/README.md
- Help: https://github.com/echasnovski/mini.indentscope/blob/main/doc/mini-indentscope.txt

## Notes
- The animation-disable line is load-bearing — re-enabling it tanks scrolling perf in large code files. If you want animation back, prefer `draw.delay` tuning and a faster `gen_animation` curve.
- The 1500-line ceiling mirrors `rainbow-delimiters` (same file) and `hlargs.nvim` — pick one number and keep them in sync.
- `BufReadPre`/`BufNewFile` event means the plugin loads as soon as you open any file; it doesn't wait for an indent change.
