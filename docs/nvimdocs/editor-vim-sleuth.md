# editor-vim-sleuth
> Auto-detects indentation (tabs vs spaces, width) from the current buffer.

**Repo:** https://github.com/tpope/vim-sleuth
**Local spec:** lua/plugins/editor.lua:3
**Tags:** indent, detection, vimscript, tpope

## Scope

`vim-sleuth` heuristically inspects each opened file and sets `shiftwidth`, `tabstop`, `softtabstop`, and `expandtab` to match what the rest of the file (or sibling files in the project) is already using. Replaces the need for `editorconfig`-only setups or per-filetype indent ftplugins.

## Install spec

```lua
{ "tpope/vim-sleuth", event = "BufReadPre" }
```

Loaded on `BufReadPre` so detection fires before the buffer renders. No `opts` — sleuth has no configuration surface beyond globals.

## Common customizations

- `vim.g.sleuth_automatic` *(bool, 1)* — auto-run on `BufNewFile`/`BufReadPost`. Set `0` to require manual `:Sleuth`.
- `vim.g.sleuth_<filetype>_heuristics` *(bool, 1)* — disable detection per filetype, e.g. `vim.g.sleuth_python_heuristics = 0`.
- `vim.g.sleuth_<filetype>_defaults` *(string)* — override fallback when detection fails, e.g. `"shiftwidth=2 expandtab"`.
- `vim.g.sleuth_neighbor_limit` *(integer, 8)* — max sibling files probed when current file is empty.
- `vim.g.sleuth_editorconfig` *(bool, 1)* — respect `.editorconfig` if present; set `0` to ignore.

WebFetch https://raw.githubusercontent.com/tpope/vim-sleuth/HEAD/README.markdown if uncertain.

## Our config

Zero configuration. Sleuth runs with defaults, defers to `.editorconfig` when one exists, and otherwise probes the current buffer + up to 8 neighbours.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `:Sleuth` | cmd | manual re-detection | Re-run heuristics on current buffer |

No keybinds.

## Links

- Plugin repo: https://github.com/tpope/vim-sleuth
- Help: `:help sleuth`

## Notes

- Detection is silent on success. To debug, run `:verbose set shiftwidth?` after opening a file — output should mention sleuth.
- Sleuth defers to LSP-attached language servers that set indent themselves (e.g., gopls forces tabs).
- Coexists with `vim.bo.expandtab` user settings — sleuth only changes them if it has high confidence.
