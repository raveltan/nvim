# editor-highlight-undo
> Briefly flash the region affected by `u` / `<C-r>` so you see what changed.

**Repo:** https://github.com/tzachar/highlight-undo.nvim
**Local spec:** lua/plugins/editor.lua:551-554
**Tags:** undo, redo, highlight, feedback, editor

## Scope

`highlight-undo.nvim` wraps `u` and `<C-r>` (plus optional `p`/`P`) so the buffer range touched by the operation flashes with a highlight group for a moment. Eliminates the "did anything happen?" confusion on multi-line undos.

## Install spec

```lua
{
  "tzachar/highlight-undo.nvim",
  keys = { "u", "<C-r>" },
  opts = {},
}
```

Lazy-loaded on `u`/`<C-r>` so it costs nothing until you actually undo something.

## Common customizations

- `duration` *(integer, 300)* — ms the highlight stays before fading.
- `undo.hlgroup` *(string, "HighlightUndo")* — highlight group for undo flash. Define your own or link via `:hi link HighlightUndo IncSearch`.
- `undo.mode` *(string, "n")* — modes the keymap applies to.
- `undo.lhs` *(string, "u")* — left-hand side; change if you've remapped undo.
- `undo.map` *(string, "undo")* — vim command invoked under the hood.
- `undo.opts` *(table, {})* — extra `vim.keymap.set` opts.
- `redo.hlgroup` *(string, "HighlightUndo")* — highlight for `<C-r>`.
- `redo.lhs` *(string, "<C-r>")*.
- `redo.map` *(string, "redo")*.
- `highlight_for_count` *(bool, true)* — also highlight when undo is prefixed with a count.

You can add custom entries (e.g. for `p`/`P` paste) by passing extra named tables alongside `undo`/`redo`. WebFetch https://raw.githubusercontent.com/tzachar/highlight-undo.nvim/HEAD/README.md if uncertain about option keys.

## Our config

Empty `opts = {}` — all defaults. `u` flashes undo, `<C-r>` flashes redo, both using `HighlightUndo` (which links to a sensible default; tweak with `:hi` if too subtle on your colourscheme).

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `u` | n | undo + flash region | Builtin undo, with highlight |
| `<C-r>` | n | redo + flash region | Builtin redo, with highlight |

## Links

- Plugin repo: https://github.com/tzachar/highlight-undo.nvim

## Notes

- If the flash is invisible, your colourscheme probably doesn't define `HighlightUndo`. Add `vim.api.nvim_set_hl(0, "HighlightUndo", { bg = "#3a3a3a" })` or link it to `IncSearch`.
- The plugin uses `vim.on_key` + extmarks — it does not touch the undo tree itself, so `:undolist`, `g-`/`g+`, undotree.vim all work normally.
- For paste flashing, prefer `vim.highlight.on_yank` and yanky's built-in highlights rather than extending this plugin.
