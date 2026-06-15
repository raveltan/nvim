# util-line-history
> `git log` for the current line, range, or whole file — in a snacks picker with full-diff preview; opens the commit read-only.

**Local spec:** lua/util/line_history.lua:1-128
**Tags:** git, log, history, snacks, util

## Scope
Lists every commit that touched a target (a line range via `git log -L`, or the whole file via `git log --follow`), formatted as `sha when author subject` with a per-commit `git show --stat -p` preview on the right. Confirming an item opens that commit via `:Gedit <sha>` (fugitive) — read-only, correct filetype, and crucially **never checks the commit out**. Drives `<leader>gl` (line/range) and `<leader>gf` (file).

## Install spec
Internal module — required from `lua/plugins/git.lua` keymaps:

```lua
require("util.line_history").pick()        -- current line
require("util.line_history").pick(s, e)    -- explicit range
require("util.line_history").file()        -- whole current file
```

## Public API
- `M.pick(s?, e?)` — picker of commits touching line range `[s, e]` (`git log -L<s>,<e>:<file>`). Omitting both args falls back to the cursor line. Bound to `<leader>gl` (n + v).
- `M.file()` — picker of commits touching the whole current file (`git log --follow -- <file>`, tracks renames). Bound to `<leader>gf`.

Both resolve the path with `expand("%:p")` → `fnamemodify(:., ":.")` (repo-relative), and notify + bail on an unnamed buffer, non-zero git exit, or zero commits.

Internal helpers (not exported):
- `get_range(s, e)` — returns `(s, e)` when both provided, else the cursor line.
- `pick_commits(opts)` — the shared engine both public functions call with `{ source, title, log_args, rel, empty_msg }`.

The shared picker:
- Listing query: `git log -n 200 --no-patch --pretty=format:%h\t%an\t%ar\t%s` plus `opts.log_args` (the only difference between line/file mode). `-n 200` bounds worst-case latency on old files.
- Runs **async** via `vim.system` + `vim.schedule_wrap` so a long `git log -L` never freezes the UI.
- `items` shaped `{ text, sha }`; `format` returns a single-segment row of `item.text`.
- `preview` runs `git show --stat -p <sha> -- <rel>`, **async + cached** (`show_cache` keyed by `sha:rel`); a `preview_gen` token drops stale `git show` results if the selection moved on.
- `confirm` closes the picker then runs `:Gedit <sha>`.

## Our config
Bound in `lua/plugins/git.lua` (fugitive `keys`):
- `<leader>gl` (n) → `pick()` (cursor line).
- `<leader>gl` (v) → captures `line("v")`/`line(".")`, exits visual mode with `<Esc>` (raw `\27`), normalises so `s <= e`, then `pick(s, e)`.
- `<leader>gf` (n) → `file()`.

## Keymaps
The module exposes no keymaps itself; see git-fugitive.md for the bindings.

## Links
- `git log -L`: https://git-scm.com/docs/git-log#Documentation/git-log.txt--Lltstartgtltendgtltfilegt
- Fugitive `:Gedit`: https://github.com/tpope/vim-fugitive/blob/master/doc/fugitive.txt
- Snacks picker: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md

## Notes
- **Why this exists instead of snacks `git_log_line`/`git_log_file`:** those built-in snacks sources default their `confirm` action to `git checkout <commit>` — selecting a commit detaches HEAD onto it. This util keeps the same picker+preview UX but confirms with `:Gedit <sha>` (open read-only, no working-tree change).
- `git log -L` is line-trace mode — it follows the range across renames and reshaping patches, which is why line history is a separate query from `:Gclog`.
- `--no-patch` keeps the listing to one row per commit; the patch is fetched on demand by the preview callback (cheap — one commit at a time, then cached).
- Pretty format `%h\t%an\t%ar\t%s` uses tabs so author names containing spaces parse correctly with the `([^\t]*)` patterns.
- `confirm` relies on fugitive's `:Gedit <sha>` — fugitive is in the `cmd` table, so calling `:Gedit` triggers its lazy load.
- The visual-mode keymap dispatches `<Esc>` before reading `line("v")`/`line(".")` so the marks aren't stale.
