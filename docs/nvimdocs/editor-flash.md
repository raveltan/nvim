# editor-flash
> Label-based jump navigation across the visible window, treesitter nodes, and remote operators.

**Repo:** https://github.com/folke/flash.nvim
**Local spec:** lua/plugins/editor.lua:77-91
**Tags:** motion, navigation, treesitter, search

## Scope
Adds jump labels for fast cursor motion: `s` to flash-jump anywhere on screen, `S` to select a treesitter node, plus operator-pending and visual-mode variants for remote actions and treesitter-aware search. Enhances `f/F/t/T` via the `char` mode so single-char jumps gain labels and repeat motions.

## Install spec
```lua
{
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {
    modes = {
      char = { enabled = true },
    },
  },
  keys = { ... },
}
```

## Common customizations
- `labels` *(string, "asdfghjklqwertyuiopzxcvbnmABCDE…")* — label characters in priority order.
- `search.multi_window` *(bool, true)* — flash across all visible windows.
- `search.forward` *(bool, true)* — default search direction.
- `search.wrap` *(bool, true)* — wrap around at file edges.
- `jump.autojump` *(bool, false)* — auto-jump when only one match remains.
- `jump.nohlsearch` *(bool, false)* — clear hlsearch after jumping.
- `modes.char.enabled` *(bool, true)* — enables labelled `f/F/t/T/;/,`.
- `modes.char.jump_labels` *(bool, false)* — show labels on `f/F/t/T` too.
- `modes.search.enabled` *(bool, true)* — labels for `/` and `?`.
- `modes.treesitter` — config for `S` selection (`labels`, `jump`, `highlight`).
- `prompt.enabled` *(bool, true)* — show prompt window during input.
- `highlight.backdrop` *(bool, true)* — dim the rest of the buffer.

## Our config
- `modes.char.enabled = true` — explicit (matches upstream default; kept for clarity).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `s` | n / x / o | `require("flash").jump()` | Flash jump |
| `S` | n / x / o | `require("flash").treesitter()` | Flash treesitter node |
| `r` | o | `require("flash").remote()` | Remote flash (operate on distant region) |
| `R` | o / x | `require("flash").treesitter_search()` | Treesitter-aware search |
| `<C-s>` | c | `require("flash").toggle()` | Toggle flash during `/` search |

## Links
- README: https://github.com/folke/flash.nvim/blob/main/README.md
- Default opts: https://github.com/folke/flash.nvim/blob/main/lua/flash/config.lua

## Notes
- `r` overrides the default operator-pending `r` (replace char), but only after an operator — normal-mode `r` still works.
- `S` in operator mode performs a treesitter selection; useful in chains like `yS` (yank node).
- `char` mode is opt-in upstream; we enable it so `f<char>` shows labels for repeat motions.
