# git-gitsigns
> Sign-column git indicators and hunk navigation/actions.

**Repo:** https://github.com/lewis6991/gitsigns.nvim
**Local spec:** lua/plugins/git.lua:3-52
**Tags:** git, signs, hunk

## Scope
Decorates the sign column with add/change/delete marks per hunk and exposes hunk navigation and a trimmed set of actions through a buffer-local `on_attach`. Loads on `BufReadPost`/`BufNewFile` so signs appear as soon as a buffer is opened in a git repo.

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
- `signs` *(table, `add=┃ change=┃ delete=_ topdelete=‾ changedelete=~`)* — per-status sign glyphs.
- `signcolumn` *(bool, true)* — show signs in `signcolumn`; set false to use `numhl` instead.
- `numhl` *(bool, false)* — highlight line numbers instead of signs.
- `linehl` *(bool, false)* — highlight whole changed lines.
- `word_diff` *(bool, false)* — inline word-level diff highlight.
- `current_line_blame` *(bool, false)* — virt-text blame on the cursor line.
- `attach_to_untracked` *(bool, false)* — also attach to untracked files.
- `update_debounce` *(number, 100)* — ms debounce for sign refresh.
- `max_file_length` *(number, 40000)* — skip files longer than this.
- `watch_gitdir.follow_files` *(bool, true)* — track renames inside the repo.
- `preview_config` *(table)* — floating preview window style.

## Our config
- Custom `signs` glyphs (thick bars for add/change, underscore/overline for delete variants).
- Current-line blame is **not** enabled (no `current_line_blame`) — for per-line history use `<leader>gl` (line_history util).
- `on_attach` defines the buffer-local keymaps below.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `]c` | n | `gs.nav_hunk("next")` then `zz` (or `]c` in diff mode) | Next hunk (centered) |
| `[c` | n | `gs.nav_hunk("prev")` then `zz` (or `[c` in diff mode) | Prev hunk (centered) |
| `<leader>gp` | n | `gs.preview_hunk_inline` | Preview hunk inline |
| `<leader>gr` | n | `gs.reset_hunk` | Reset hunk |
| `<leader>gr` | v | `gs.reset_hunk({line("."), line("v")})` | Reset selected lines |

## Links
- README: https://github.com/lewis6991/gitsigns.nvim/blob/main/README.md
- `:help gitsigns` — full API reference.

## Notes
- `]c`/`[c` fall back to Vim's native diff-mode motions when `&diff` is set, so the same keys work inside `:Gdiffsplit` windows; both re-center the cursor with `zz` after jumping.
- Hunk actions are deliberately minimal and promoted to the top-level `<leader>g` prefix: only inline preview (`<leader>gp`) and reset (`<leader>gr`). The old `<leader>gh*` hunk subgroup was removed.
- Staging/unstaging is **not** bound here — use lazygit (`<leader>gg`) or `:Git` (fugitive) for staging.
- Blame is no longer a gitsigns keymap. For per-line / per-file commit history use `<leader>gl` / `<leader>gf` (line_history util); both open the commit read-only via `:Gedit`.
