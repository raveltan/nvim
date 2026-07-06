# nav-harpoon
> Mark a handful of "pinned" files and teleport to them with `<leader>1..8`.

**Repo:** https://github.com/ThePrimeagen/harpoon (branch `harpoon2`)
**Local spec:** lua/plugins/nav.lua:44
**Tags:** navigation, marks, bookmarks, files

## Scope
Maintains a small per-project list of pinned files (a "harpoon list"). Hop directly to slot N with one keystroke, without re-fuzzy-finding. Complements fff.nvim: fff for discovery, harpoon for the 3-8 files you're actively cycling. Branch `harpoon2` is the current rewrite with the `:list():add()/select()` API.

## Install spec
```lua
{
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Add file" },
    { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Toggle menu" },
    { "<leader>1", function() require("harpoon"):list():select(1) end, desc = "Harpoon file 1" },
    -- ... <leader>2..8 mirror the above
  },
  config = function()
    require("harpoon"):setup()
  end,
}
```

## Common customizations
- `settings.save_on_toggle` *(bool, false)* — persist list when closing the quick menu.
- `settings.sync_on_ui_close` *(bool, false)* — write to disk on UI close.
- `settings.key` *(fn, project root)* — function returning the list key (defaults to `vim.loop.cwd()`); override to scope by branch, etc.
- `default.create_list_item` *(fn)* — customize how an entry is built (e.g. include cursor position).
- `default.select` *(fn)* — override what "select" does (e.g. open in split).
- Per-list overrides — pass a name to `:list("name")` for separate lists (e.g. terminals, cmds).

## Our config
- Vanilla `require("harpoon"):setup()` — no option overrides.
- Slots 1-8 bound (upstream examples usually show 1-4).
- No `delete` or `prev/next` mappings — the quick menu (`<leader>hh`) is the editing surface.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>ha` | n | `harpoon:list():add()` | Pin current file |
| `<leader>hh` | n | `harpoon.ui:toggle_quick_menu(...)` | Toggle quick menu |
| `<leader>1` | n | `harpoon:list():select(1)` | Jump to slot 1 |
| `<leader>2` | n | `harpoon:list():select(2)` | Jump to slot 2 |
| `<leader>3` | n | `harpoon:list():select(3)` | Jump to slot 3 |
| `<leader>4` | n | `harpoon:list():select(4)` | Jump to slot 4 |
| `<leader>5` | n | `harpoon:list():select(5)` | Jump to slot 5 |
| `<leader>6` | n | `harpoon:list():select(6)` | Jump to slot 6 |
| `<leader>7` | n | `harpoon:list():select(7)` | Jump to slot 7 |
| `<leader>8` | n | `harpoon:list():select(8)` | Jump to slot 8 |

## Links
- README (harpoon2): https://github.com/ThePrimeagen/harpoon/blob/harpoon2/README.md
- API contract: https://github.com/ThePrimeagen/harpoon/blob/harpoon2/lua/harpoon/init.lua

## Notes
- Inside the quick menu (`<leader>hh`): edit the buffer like a list — reorder lines, delete lines, `:w` to save. `<CR>` jumps to the entry under the cursor.
- Lists are persisted per cwd at `vim.fn.stdpath("data") .. "/harpoon/harpoon.json"`.
- `branch = "harpoon2"` is mandatory; the default `master` branch is the legacy v1 API and will break these keymaps.
- Combine with fff.nvim's `<leader><leader>` to find a file, then `<leader>ha` to pin it.
