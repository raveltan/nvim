# editor-multicursor
> VSCode-style multi-cursor editing — add cursors at matches, on lines, or by mouse click.

**Repo:** https://github.com/jake-stewart/multicursor.nvim
**Local spec:** lua/plugins/editor.lua:154-193
**Tags:** multicursor, editing, motion

## Scope
Adds and manages a set of extra cursors that mirror normal-mode and visual-mode edits in real time. Supports match-based addition (next/prev occurrence of word/selection), line-based addition (above/below), align/transpose helpers, and a keymap layer that activates only while extra cursors exist.

## Install spec
```lua
{
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  keys = { ... },
  config = function()
    local mc = require("multicursor-nvim")
    mc.setup()
    mc.addKeymapLayer(function(layerSet)
      layerSet({ "n", "x" }, "<left>", mc.prevCursor)
      layerSet({ "n", "x" }, "<right>", mc.nextCursor)
      layerSet({ "n", "x" }, "<tab>", mc.nextCursor)
      layerSet({ "n", "x" }, "<s-tab>", mc.prevCursor)
      layerSet("n", "<esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        else
          mc.clearCursors()
        end
      end)
    end)
  end,
}
```

## Common customizations
- `setup({ shallowUndo = false })` — share undo across cursors vs. per-cursor.
- `setup({ signs = { "│", "┃", "┃" } })` — sign column glyphs (main / disabled / extra).
- `setup({ hlsearch = false })` — disable hlsearch while cursors active.
- `addKeymapLayer(fn)` — register keys that only bind while extra cursors exist; auto-removed on `clearCursors`.
- API actions used in our config: `matchAddCursor(dir)`, `matchSkipCursor(dir)`, `matchAllAddCursors()`, `deleteCursor()`, `lineAddCursor(dir)`, `lineSkipCursor(dir)`, `restoreCursors()`, `alignCursors()`, `splitCursors()`, `transposeCursors(dir)`, `toggleCursor()`, `handleMouse()`, `prevCursor()`, `nextCursor()`, `cursorsEnabled()`, `enableCursors()`, `clearCursors()`.

## Our config
- Pinned to `branch = "1.0"` (stable API).
- Cursor layer (active only while >1 cursor exists):
  - `<left>` / `<right>` — focus prev/next cursor.
  - `<tab>` / `<s-tab>` — focus next/prev cursor.
  - `<esc>` — first press disables extra cursors, second clears them.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>mn` | n / x | `matchAddCursor(1)` | Add cursor at next match |
| `<leader>mN` | n / x | `matchAddCursor(-1)` | Add cursor at prev match |
| `<leader>ms` | n / x | `matchSkipCursor(1)` | Skip current, jump to next match |
| `<leader>mS` | n / x | `matchSkipCursor(-1)` | Skip current, jump to prev match |
| `<leader>ma` | n / x | `matchAllAddCursors` | Add cursor at every match |
| `<leader>mx` | n / x | `deleteCursor` | Remove cursor under main |
| `<leader>mj` | n / x | `lineAddCursor(1)` | Add cursor on line below |
| `<leader>mk` | n / x | `lineAddCursor(-1)` | Add cursor on line above |
| `<leader>mJ` | n / x | `lineSkipCursor(1)` | Skip current, add cursor further down |
| `<leader>mK` | n / x | `lineSkipCursor(-1)` | Skip current, add cursor further up |
| `<leader>mr` | n | `restoreCursors` | Restore last cleared cursor set |
| `<leader>ml` | n / x | `alignCursors` | Align cursors on their columns |
| `<leader>mp` | x | `splitCursors` | Split visual selection by regex into cursors |
| `<leader>mt` | x | `transposeCursors(1)` | Transpose text across cursors |
| `<C-q>` | n / x | `toggleCursor` | Toggle a cursor under cursor position |
| `<C-LeftMouse>` | n | `handleMouse` | Toggle cursor at mouse click |
| `<left>` / `<right>` | n / x (layer) | prev/next cursor | Focus other cursor |
| `<tab>` / `<s-tab>` | n / x (layer) | next/prev cursor | Focus other cursor |
| `<esc>` | n (layer) | disable → clear | Two-step exit |

## Links
- README: https://github.com/jake-stewart/multicursor.nvim/blob/main/README.md
- `:help multicursor` (after install)

## Notes
- Which-key labels `<leader>m` as the `multicursor` group (editor.lua:304).
- The keymap layer keeps `<tab>` / `<esc>` doing their normal things when no extra cursors exist.
- `branch = "1.0"` avoids breaking changes from the main branch.
