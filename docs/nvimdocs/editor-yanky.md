# editor-yanky
> Persistent yank history ring with cycling through previous yanks after paste.

**Repo:** https://github.com/gbprod/yanky.nvim
**Local spec:** lua/plugins/editor.lua:175
**Tags:** yank, paste, clipboard, history

## Scope
Records every yank into a ring buffer (100 entries here) and lets `<C-p>`/`<C-n>` cycle through that history immediately after a paste, replacing the just-pasted text with the previous/next yank. Wraps `y`, `p`, `P` via `<Plug>` mappings so normal motions still work.

## Install spec
```lua
{
  "gbprod/yanky.nvim",
  event = "VeryLazy",
  opts = {
    ring = { history_length = 100 },
  },
  keys = { ... },
}
```

## Common customizations
- `ring.history_length` *(number, 100)* — how many past yanks to keep.
- `ring.storage` *(string, "shada")* — `shada`, `sqlite`, or `memory`. `shada` persists across sessions via Neovim's shada file.
- `ring.sync_with_numbered_registers` *(bool, true)* — also write to `"0`-`"9` registers.
- `ring.cancel_event` *(string, "update")* — when cycling stops being available.
- `ring.ignore_registers` *(table, { "_" })* — registers excluded from the ring.
- `ring.update_register_on_cycle` *(bool, false)* — overwrite the unnamed register on cycle.
- `picker.select.action` *(function|nil, nil)* — action when picking via `:YankyRingHistory`.
- `picker.telescope.use_default_mappings` *(bool, true)* — enable telescope picker if installed.
- `system_clipboard.sync_with_ring` *(bool, true)* — capture external clipboard changes.
- `highlight.on_put` / `highlight.on_yank` *(bool, true)* — flash region after action.
- `highlight.timer` *(number, 500)* — flash duration in ms.
- `preserve_cursor_position.enabled` *(bool, true)* — keep cursor on yank.
- `textobj.enabled` *(bool, false)* — adds `iy`/`ay` text objects over last paste.

## Our config
- `ring.history_length = 100` (default is 100 too; explicit here).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `y` | n / x | `<Plug>(YankyYank)` | Yank (records to ring) |
| `p` | n / x | `<Plug>(YankyPutAfter)` | Put after cursor |
| `P` | n / x | `<Plug>(YankyPutBefore)` | Put before cursor |
| `<C-p>` | n | `<Plug>(YankyPreviousEntry)` | Replace last paste with older yank |
| `<C-n>` | n | `<Plug>(YankyNextEntry)` | Replace last paste with newer yank |

## Links
- README: https://github.com/gbprod/yanky.nvim/blob/main/README.md
- Default opts: https://github.com/gbprod/yanky.nvim/blob/main/lua/yanky/config.lua

## Notes
- `<C-p>` / `<C-n>` only work immediately after a put, until the next motion/edit.
- Combine with snacks picker (`Snacks.picker.yank_history()`) for an interactive picker.
- shada storage means yanks survive Neovim restart.
