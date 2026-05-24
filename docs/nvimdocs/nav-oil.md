# nav-oil
> Edit your filesystem like a normal Neovim buffer — `-` opens the parent directory.

**Repo:** https://github.com/stevearc/oil.nvim
**Local spec:** lua/plugins/nav.lua:20-39
**Tags:** explorer, filesystem, buffer, navigation

## Scope
Replaces netrw with a buffer-based file explorer. Each directory opens as a regular buffer whose lines are filenames; standard editing commands (`dd` delete, `p` paste, `cw` rename, `o` new file) become filesystem operations on `:w`. Acts as the default file explorer so `:edit <dir>` and `nvim <dir>` route through Oil.

## Install spec
```lua
{
  "stevearc/oil.nvim",
  dependencies = { "echasnovski/mini.icons" },
  keys = {
    { "<leader>e", "<cmd>Oil<cr>", desc = "Explorer (Oil)" },
    { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
  },
  opts = {
    default_file_explorer = true,
    columns = { "icon" },
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["q"] = "actions.close",
      ["<C-h>"] = false,
      ["<C-l>"] = false,
    },
  },
}
```

## Common customizations
- `default_file_explorer` *(bool, true)* — take over from netrw.
- `columns` *(table, {"icon"})* — visible columns; add `"permissions"`, `"size"`, `"mtime"` for ls-style detail.
- `view_options.show_hidden` *(bool, false)* — show dotfiles.
- `view_options.is_hidden_file` *(fn, nil)* — custom predicate for hidden files.
- `view_options.natural_order` *(bool, true)* — natural-sort numeric filenames.
- `delete_to_trash` *(bool, false)* — send deletions to system trash instead of `rm`.
- `skip_confirm_for_simple_edits` *(bool, false)* — don't prompt on uncomplicated changes.
- `prompt_save_on_select_new_entry` *(bool, true)* — confirm save when opening a freshly-created entry.
- `float` *(table)* — floating-window appearance (`max_width`, `max_height`, `border`).
- `keymaps` *(table)* — override per-action keys; set to `false` to unmap.
- `lsp_file_methods` *(table)* — control LSP `willRenameFiles` notifications.

## Our config
- `default_file_explorer = true` — Oil owns dir buffers.
- `columns = { "icon" }` — minimal: just an icon + name.
- `view_options.show_hidden = true` — dotfiles visible by default.
- `keymaps["q"] = "actions.close"` — `q` exits the Oil buffer.
- `keymaps["<C-h>"] = false`, `keymaps["<C-l>"] = false` — yield to vim-tmux-navigator inside Oil.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>e` | n | `:Oil` | Open explorer at current buffer's dir |
| `-` | n | `:Oil` | Open parent directory |
| `q` | n (oil buf) | `actions.close` | Close Oil buffer |
| `<CR>` | n (oil buf) | `actions.select` | Open file / enter dir |
| `-` | n (oil buf) | `actions.parent` | Go up one level |
| `_` | n (oil buf) | `actions.open_cwd` | Jump to cwd |
| `g.` | n (oil buf) | `actions.toggle_hidden` | Toggle dotfiles |
| `g?` | n (oil buf) | `actions.show_help` | Show all default mappings |

## Links
- README: https://github.com/stevearc/oil.nvim/blob/master/README.md
- Recipes: https://github.com/stevearc/oil.nvim/blob/master/doc/recipes.md
- Default keymaps: https://github.com/stevearc/oil.nvim/blob/master/lua/oil/config.lua

## Notes
- Editing is transactional: changes apply on `:w`. Review the diff prompt before confirming destructive ops.
- `dd` then `:w` deletes a file; `p` in a different dir buffer pastes/moves it.
- `mini.icons` is the icon backend; `nvim-web-devicons` works as a swap-in if preferred.
- Disabling `<C-h>`/`<C-l>` here is intentional — tmux/window navigation must keep working inside Oil.
