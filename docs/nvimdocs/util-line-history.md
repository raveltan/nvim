# util-line-history
> `git log -L` for the current line or visual range, presented in a snacks picker with full-diff preview.

**Local spec:** lua/util/line_history.lua:1-63
**Tags:** git, log, blame, snacks, util

## Scope
Wraps `git log -L<s>,<e>:<file>` to list every commit that touched a specific line range, formatted as `sha author when subject` with a per-commit `git show --stat -p` preview. Confirming an item opens that revision of the file via `:Gedit <sha>` (fugitive), so the buffer is read-only with the right filetype/syntax. Drives the `<leader>gl` keymap in normal and visual mode.

## Install spec
Internal module — required from `lua/plugins/git.lua` keymaps:

```lua
require("util.line_history").pick()        -- current line
require("util.line_history").pick(s, e)    -- explicit range
```

## Public API
- `M.pick(s?, e?)` — open the picker for line range `[s, e]`. When both args are omitted, falls back to the cursor line (`s = e = line(".")`). Resolves the file path with `expand("%:p")` then `fnamemodify(:., ":.")` so git sees a repo-relative path. Notifies and bails on:
  - empty filename (unnamed buffer),
  - non-zero git exit or zero commits.

Internal helper (not exported):
- `get_range(s, e)` — returns `(s, e)` when both provided, else `(line("."), line("."))`.

The picker invocation:
- `source = "line_history"`, `title = "Line history <s>-<e> : <rel>"`.
- `items` shaped `{ text, sha, author, when, subject }`. `format` returns a single-segment row of `item.text`.
- `preview` runs `git show --stat -p <sha> -- <rel>`, sets buffer lines, and highlights with `ft = "git"`.
- `confirm` closes the picker then `:Gedit <sha>` to open that file revision.

## Our config
Bound in `lua/plugins/git.lua`:
- `<leader>gl` (n) → `pick()` (cursor line).
- `<leader>gl` (v) → captures `line("v")`/`line(".")`, exits visual mode with `<Esc>` (raw `\27`), normalises so `s <= e`, then `pick(s, e)`.

## Keymaps
The module exposes no keymaps itself; see git-fugitive.md for the bindings.

## Links
- `git log -L`: https://git-scm.com/docs/git-log#Documentation/git-log.txt--Lltstartgtltendgtltfilegt
- Fugitive `:Gedit`: https://github.com/tpope/vim-fugitive/blob/master/doc/fugitive.txt
- Snacks picker: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md

## Notes
- `git log -L` is line-trace mode — it follows the range across renames and through patches that re-shape the surrounding code, which is why this util exists separately from plain `:Gclog`.
- `--no-patch` is used in the listing query so we only get one row per commit; the patch is fetched on demand by the preview callback (cheap because it's one commit at a time).
- Pretty format `%h\t%an\t%ar\t%s` uses tabs so author names containing spaces parse correctly with the `([^\t]*)` patterns.
- `confirm` relies on fugitive's `:Gedit <sha>` — make sure vim-fugitive is loaded (it's listed in the fugitive `cmd` table, so just calling `:Gedit` triggers lazy load).
- The visual-mode keymap dispatches `<Esc>` via `vim.cmd("normal! \27")` to leave visual mode before reading `line("v")`/`line(".")` would otherwise give stale values across the picker open.
