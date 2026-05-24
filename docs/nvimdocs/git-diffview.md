# git-diffview
> Tab-based diff and file-history viewer with a 3-way merge layout.

**Repo:** https://github.com/sindrets/diffview.nvim
**Local spec:** lua/plugins/git.lua:64-76
**Tags:** git, diff, history, merge

## Scope
Opens a dedicated tabpage showing the working-tree (or any rev range) diff with a file panel on the left and side-by-side diff windows on the right. `:DiffviewFileHistory` plots the commit history of a path with full per-commit diffs in the same UI. Lazy-loaded by `:Diffview*` commands and the `<leader>gd`/`<leader>gf` keys.

## Install spec
```lua
{
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
  },
  opts = {
    view = { merge_tool = { layout = "diff3_mixed" } },
  },
}
```

## Common customizations
- `diff_binaries` *(bool, false)* — diff binary files too.
- `enhanced_diff_hl` *(bool, false)* — extra word-level diff highlighting.
- `view.default.layout` *(string, "diff2_horizontal")* — `diff2_horizontal`, `diff2_vertical`, `diff3_horizontal`, `diff3_vertical`, `diff3_mixed`, `diff4_mixed`.
- `view.merge_tool.layout` *(string, "diff3_horizontal")* — layout used when viewing a file with merge conflicts.
- `view.merge_tool.disable_diagnostics` *(bool, true)* — silence LSP diagnostics in merge mode.
- `file_panel.listing_style` *(string, "tree")* — `tree` or `list`.
- `file_panel.win_config` *(table)* — position/size of the file panel.
- `file_history_panel.log_options` *(table)* — `git log` flags (`max_count`, `follow`, `all`, `merges`…).
- `hooks.diff_buf_read`, `hooks.view_opened`, … *(fn)* — per-event callbacks.
- `keymaps` *(table)* — full per-view keymap table (see `:help diffview-config-keymaps`).

## Our config
- `view.merge_tool.layout = "diff3_mixed"` — show OURS/BASE/THEIRS with the working copy in the centre when resolving conflicts; pairs with git-conflict.nvim.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>gd` | n | `:DiffviewOpen` | Open diff vs index/HEAD |
| `<leader>gf` | n | `:DiffviewFileHistory %` | Current file's history |

In-view defaults (not overridden): `]c`/`[c` next/prev change, `<Tab>`/`<S-Tab>` next/prev entry in panel, `g?` help, `gf` open file under cursor, `<C-w>gf` open in new tab.

## Links
- README: https://github.com/sindrets/diffview.nvim/blob/main/README.md
- `:help diffview` — full reference.

## Notes
- `:DiffviewOpen HEAD~5` diffs HEAD vs HEAD~5; `:DiffviewOpen main...feature` shows the merge-base range.
- `:DiffviewFileHistory` with no args shows history for the whole repo; `%` (our binding) scopes it to the current file.
- Close with `:DiffviewClose` or `:tabclose` — the file panel does not respond to plain `:q`.
- For line-scoped history use `<leader>gl` (line_history util) instead; diffview only filters by file path.
