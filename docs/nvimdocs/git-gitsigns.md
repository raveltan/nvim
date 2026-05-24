# git-gitsigns
> Sign-column git indicators, current-line blame virtual text, and hunk navigation/actions.

**Repo:** https://github.com/lewis6991/gitsigns.nvim
**Local spec:** lua/plugins/git.lua:4-53
**Tags:** git, signs, blame, hunk

## Scope
Decorates the sign column with add/change/delete marks per hunk, shows commit-author virtual text on the current line after a delay, and exposes hunk navigation and actions through a buffer-local `on_attach`. Loads on `BufReadPost`/`BufNewFile` so signs appear as soon as a buffer is opened in a git repo.

## Install spec
```lua
{
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("gitsigns").setup({ ... })
  end,
}
```

## Common customizations
- `signs` *(table, `add=┃ change=┃ delete=_ topdelete=‾ changedelete=~ untracked=┆`)* — per-status sign glyphs.
- `signcolumn` *(bool, true)* — show signs in `signcolumn`; set false to use `numhl` instead.
- `numhl` *(bool, false)* — highlight line numbers instead of signs.
- `linehl` *(bool, false)* — highlight whole changed lines.
- `word_diff` *(bool, false)* — inline word-level diff highlight.
- `current_line_blame` *(bool, false)* — virt-text blame on the cursor line.
- `current_line_blame_opts.delay` *(number, 1000)* — ms before blame appears.
- `current_line_blame_opts.virt_text_pos` *(string, "eol")* — `eol`, `overlay`, or `right_align`.
- `current_line_blame_formatter` *(string, `<author>, <author_time:%R> - <summary>`)* — blame format.
- `attach_to_untracked` *(bool, false)* — also attach to untracked files.
- `update_debounce` *(number, 100)* — ms debounce for sign refresh.
- `max_file_length` *(number, 40000)* — skip files longer than this.
- `watch_gitdir.follow_files` *(bool, true)* — track renames inside the repo.
- `preview_config` *(table)* — floating preview window style.

## Our config
- Custom `signs` glyphs (thick bars for add/change, underscore/overline for delete variants).
- `current_line_blame = true` with `delay = 2000` and `virt_text_pos = "eol"` — slower than default so it doesn't flicker while scrolling.
- `current_line_blame_formatter` set explicitly (matches upstream default; pinned for clarity).
- `on_attach` defines buffer-local keymaps below.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `]c` | n | `gs.nav_hunk("next")` (or `]c` in diff mode) | Next hunk |
| `[c` | n | `gs.nav_hunk("prev")` (or `[c` in diff mode) | Prev hunk |
| `<leader>gb` | n | `gs.blame()` | Open full-file blame pane |
| `<leader>gt` | n | `gs.toggle_current_line_blame` | Toggle line-blame virt text |

## Links
- README: https://github.com/lewis6991/gitsigns.nvim/blob/main/README.md
- `:help gitsigns` — full API reference.

## Notes
- `]c`/`[c` fall back to Vim's native diff-mode motions when `&diff` is set, so the same keys work inside `:DiffviewOpen` and `:Gdiffsplit` windows.
- Hunk-action keymaps (stage, reset, preview) are intentionally not bound here — use `:Gitsigns stage_hunk` etc. or the Diffview/Fugitive UIs.
- `<leader>gb` opens the gitsigns blame pane (author column with reblame on `<CR>`). For the interactive blame buffer with commit navigation, use `<leader>gB` (fugitive).
