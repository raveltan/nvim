# editor-vim-matchup
> Smarter `%` that jumps between language constructs (if/else/end, do/end, etc.).

**Repo:** https://github.com/andymass/vim-matchup
**Local spec:** lua/plugins/editor.lua:235
**Tags:** matching, motion, treesitter, vimscript

## Scope

Native `%` only matches the pairs in `matchpairs` (default `(:)`, `{:}`, `[:]`). `vim-matchup` extends this with language-aware constructs sourced from `matchit.vim` plus its own ftplugin set — Ruby `def/end`, Lua `function/end`, shell `if/fi`, HTML tags, LaTeX `\begin/\end`, etc. Adds text objects (`a%`, `i%`), motions (`g%`, `]%`, `[%`), and an off-screen popup showing the matching line when it scrolls out of view.

## Install spec

```lua
{
  "andymass/vim-matchup",
  event = "BufReadPost",
  init = function()
    vim.g.matchup_matchparen_offscreen = { method = "popup" }
  end,
}
```

`init` runs before plugin load so the global is set in time for `plugin/matchup.vim` to read it. `BufReadPost` because the matchparen highlighter needs an actual buffer.

## Common customizations

- `vim.g.matchup_matchparen_offscreen` *(table, {method="status"})* — how to show the matching line when off-screen. `method`: `"popup"` (floating window, requires Neovim 0.5+), `"status"` (in statusline), `"status_manual"`, or `""` to disable. We use `"popup"`.
- `vim.g.matchup_matchparen_enabled` *(bool, 1)* — set `0` to disable highlighting (motions still work).
- `vim.g.matchup_matchparen_deferred` *(bool, 0)* — `1` defers highlight to idle for large files.
- `vim.g.matchup_matchparen_hi_surround_always` *(bool, 0)* — always highlight surrounding pair, not just on the match.
- `vim.g.matchup_motion_enabled` *(bool, 1)* — enable `g%`, `]%`, `[%`, `z%`.
- `vim.g.matchup_text_obj_enabled` *(bool, 1)* — enable `a%` / `i%` text objects.
- `vim.g.matchup_surround_enabled` *(bool, 0)* — opt-in surround commands (`ds%`, `cs%`).
- `vim.g.matchup_delim_noskips` *(integer, 0)* — `1` skips matches inside comments, `2` also inside strings.

WebFetch https://raw.githubusercontent.com/andymass/vim-matchup/HEAD/README.md if uncertain.

## Our config

One tweak: `matchup_matchparen_offscreen = { method = "popup" }`. When the matching line is above the viewport, a small floating window shows it instead of cluttering the statusline. Useful inside long Ruby blocks or nested HTML.

Treesitter integration is opt-in via the nvim-treesitter `matchup` module — we do **not** enable it (it can be slow on large buffers). The plain ftplugin matcher is sufficient for our languages.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `%` | n,x,o | next match in pair | Forward in matchup group |
| `g%` | n,x,o | prev match in pair | Backward in matchup group |
| `[%` | n,x,o | open of containing pair | Outer-start jump |
| `]%` | n,x,o | close of containing pair | Outer-end jump |
| `z%` | n,x,o | inside next pair | Jump into next block |
| `a%` | x,o | around match text object | Includes delimiters |
| `i%` | x,o | inside match text object | Excludes delimiters |

## Links

- Plugin repo: https://github.com/andymass/vim-matchup
- Help: `:help matchup`

## Notes

- The popup floats at the top of the window; `<C-w>w` can't focus it (intentional).
- Companion to the fold providers in [editor-folding](editor-folding.md) — matchup's text objects work well as fold targets.
- If `%` feels slow on large files, set `vim.g.matchup_matchparen_deferred = 1`.
- **On HTML/JSX tags, `%` and `i%`/`a%` are taken over by the in-repo [editor-tagmatch](editor-tagmatch.md) module** (treesitter-resolved, handles hyphenated custom elements and injected templates); matchup remains the fallback everywhere else.
