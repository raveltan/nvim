# editor-mini-bufremove
> Delete a buffer without closing the window that holds it.

**Repo:** https://github.com/echasnovski/mini.bufremove (part of https://github.com/echasnovski/mini.nvim)
**Local spec:** lua/plugins/editor.lua:149
**Tags:** buffer, window, mini

## Scope
Wraps `:bdelete` / `:bwipeout` so that closing a buffer falls back to the previous/alternate buffer in each window, instead of collapsing splits. Essential when running buffer-per-tab workflows alongside splits.

## Install spec
```lua
{
  "echasnovski/mini.bufremove",
  keys = {
    { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete buffer" },
    { "<leader>bD", function() require("mini.bufremove").delete(0, true) end,  desc = "Delete buffer (force)" },
  },
}
```

## Common customizations
- `set_vim_settings` *(bool, true)* — whether to set `hidden = true`.
- `silent` *(bool, false)* — suppress messages.

Functions (not options):
- `delete(buf_id, force)` — `:bdelete`-style; respects unsaved changes when `force=false`.
- `wipeout(buf_id, force)` — `:bwipeout`-style; also removes from jump/changelist.
- `unshow(buf_id)` — remove buffer from all windows without deleting it.
- `unshow_in_window(win_id)` — show prev buffer in a single window only.

## Our config
No options table; only keymaps. `delete(0, ...)` operates on the current buffer.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>bd` | n | `delete(0, false)` | Delete current buffer (prompt if modified) |
| `<leader>bD` | n | `delete(0, true)` | Force delete current buffer (discard changes) |

## Links
- README: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-bufremove.md
- `:help mini.bufremove`

## Notes
- Without this, `:bd` closes the window when only one buffer is shown; with it, the window stays open displaying the alternate buffer.
- Which-key labels `<leader>b` as the `buffer` group (editor.lua:289).
