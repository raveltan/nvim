# editor-undotree
> Visual side-panel for navigating Vim's persistent undo history tree.

**Repo:** https://github.com/mbbill/undotree
**Local spec:** lua/plugins/editor.lua:23-28
**Tags:** undo, history, ui, vimscript

## Scope

Neovim's undo system is not a stack but a tree — each branch you abandon stays accessible. `undotree` renders that tree in a split, lets you walk between revisions, and previews diffs against the current buffer state. Pairs naturally with `:set undofile` for cross-session history.

## Install spec

```lua
{
  "mbbill/undotree",
  keys = {
    { "<leader>cu", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
  },
}
```

Lazy-loaded on the first `<leader>cu` press — the plugin is vimscript and registers `:Undotree*` commands when sourced.

## Common customizations

All knobs are global vimscript vars (set in `init.lua` or `vim.g`, not `opts`):

- `vim.g.undotree_WindowLayout` *(integer, 1)* — 1: tree left + diff bottom; 2: tree left + diff right; 3: tree right + diff bottom; 4: tree right + diff full-height.
- `vim.g.undotree_SplitWidth` *(integer, 30)* — tree split columns.
- `vim.g.undotree_DiffpanelHeight` *(integer, 10)* — diff preview rows.
- `vim.g.undotree_DiffAutoOpen` *(bool, 1)* — auto-show diff preview.
- `vim.g.undotree_SetFocusWhenToggle` *(bool, 0)* — jump cursor into the tree on toggle. Recommended `1`.
- `vim.g.undotree_ShortIndicators` *(bool, 0)* — compact timestamps (s/m/h vs seconds/minutes/hours).
- `vim.g.undotree_HighlightChangedText` *(bool, 1)* — highlight diff text.
- `vim.g.undotree_HelpLine` *(bool, 1)* — show `? for help` footer.

WebFetch https://raw.githubusercontent.com/mbbill/undotree/HEAD/README.md if uncertain.

## Our config

No customisation — default layout (tree on left, diff at bottom). Persistent undo files are configured separately in the options module (`undofile=true`, `undodir=...`); without that the tree resets on `:q`.

## Keymaps

Single global trigger; everything else lives inside the undotree window.

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>cu` | n | `:UndotreeToggle` | Toggle undo tree |
| `j`/`k` | n (in tree) | next/prev revision | Walk tree linearly |
| `J`/`K` | n (in tree) | next/prev saved write | Jump between `:w` revisions |
| `p` | n (in tree) | preview | Show diff for hovered revision |
| `<CR>` / `o` | n (in tree) | revert | Apply hovered revision to source buffer |
| `q` | n (in tree) | close | Close undotree |
| `?` | n (in tree) | help | Inline cheatsheet |

## Links

- Plugin repo: https://github.com/mbbill/undotree
- Help: `:help undotree.txt`

## Notes

- Press `?` inside the undotree window for the full key list — it's built-in help, not documented elsewhere.
- Tree is per-buffer; switch buffers and `:UndotreeToggle` again to see that file's history.
- For long-lived undo, ensure `undodir` survives across sessions (we point it at `stdpath("state") .. "/undo"`).
