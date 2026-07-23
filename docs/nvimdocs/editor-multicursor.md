# editor-multicursor
> Multiple simultaneous cursors — add by match, by line, or all-at-once, then edit every cursor together.

**Repo:** https://github.com/jake-stewart/multicursor.nvim
**Local spec:** lua/plugins/editor.lua:475
**Tags:** multicursor, editing, motion, editor

## Scope

`multicursor.nvim` places extra cursors in the buffer so one edit or motion applies to all of them at once. Cursors are added by matching the word/selection under the cursor (`<leader>cn`/`cN`), by walking adjacent lines (`<leader>cj`/`ck`), or all matches at once (`<leader>cm`). While cursors exist, ordinary motions (`j/k/w/b`, `/`, `f/t`) and edits fan out to every cursor. A **keymap layer** activates only while multiple cursors exist, so it can safely reuse keys (arrows, `<leader>x`, `<esc>`) without a permanent conflict.

## Install spec

```lua
{
  "jake-stewart/multicursor.nvim",
  keys = { ... },        -- <leader>c{n,N,S,m,j,k,q}
  config = function()
    local mc = require("multicursor-nvim")
    mc.setup()
    mc.addKeymapLayer(function(layer) ... end)
  end,
}
```

Lazy-loaded on the `<leader>c*` keys. The layer is registered once in `config`; it self-arms whenever ≥1 extra cursor is live and disarms when they clear.

## Why these keys (not `<C-n>`)

The plugin's default `<C-n>` and every other Ctrl combo is already taken:
- `<C-n>`/`<C-p>` → yanky yank-ring cycle
- `<C-h/j/k/l>` → tmux/window navigation
- `<C-d>`/`<C-u>` → centered half-page scroll

So cursor-add maps live under `<leader>c` instead.

## Our config

- `mc.setup()` with **no opts** — all defaults.
- `lineAddCursor` calls pass `skipEmpty = false`. The default (`true`) skips every line *shorter* than the current virtual column, so starting on a long line makes `cj`/`ck` jump past (or refuse to add on) shorter lines below. `false` = always the adjacent logical line, column clamped to line end — predictable on wrapped/long lines.
- Custom keymap layer (see Keymaps → "While cursors exist").

## Keymaps

### Adding cursors (normal + visual)

| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>cn` | n / x | `matchAddCursor(1)` | Add cursor at next match of word/selection |
| `<leader>cN` | n / x | `matchAddCursor(-1)` | Add cursor at previous match |
| `<leader>cS` | n / x | `matchSkipCursor(1)` | Skip current, jump main cursor to next match |
| `<leader>cm` | n / x | `matchAllAddCursors()` | Add a cursor at every match in the buffer |
| `<leader>cj` | n / x | `lineAddCursor(1, {skipEmpty=false})` | Add cursor on line below |
| `<leader>ck` | n / x | `lineAddCursor(-1, {skipEmpty=false})` | Add cursor on line above |
| `<leader>cq` | n / x | `toggleCursor()` | Freeze others / place a cursor here |

### While cursors exist (layer — active only with ≥2 cursors)

| Key | Mode | Action | Desc |
|---|---|---|---|
| `<left>` | n / x | `prevCursor` | Focus previous cursor |
| `<right>` | n / x | `nextCursor` | Focus next cursor |
| `<leader>x` | n / x | `deleteCursor` | Drop the focused cursor |
| `<esc>` | n | freeze→unfreeze **or** clear all | If frozen: unfreeze (keep main's new position). If enabled: remove all extra cursors (exit). |

## Workflow: reposition one cursor

While cursors are enabled, plain motions move *every* cursor. To move just one:

1. `<leader>cq` — freezes the other cursors so plain motions move only the main cursor.
2. Roam to the target spot with normal motions.
3. `<leader>cq` again — drops a cursor there.
4. `<esc>` — unfreezes.

## Links

- README: https://github.com/jake-stewart/multicursor.nvim/blob/main/README.md
- API list: https://github.com/jake-stewart/multicursor.nvim#api

## Notes

- Add-cursor maps work in **visual** mode too (`x`) — select text, `<leader>cn` matches that selection.
- `<esc>` is overloaded inside the layer: first press unfreezes a `cq` freeze; when nothing is frozen it clears all extra cursors (the exit). Not bound outside the layer, so normal `<esc>` (clear search highlight) is untouched.
- The layer reuses `<leader>x` and the arrow keys — safe because it only exists while multiple cursors are live.
