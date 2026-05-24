# util-ggrep
> Run `git grep` from the current buffer's repo and show results in a snacks picker with preview.

**Local spec:** lua/util/ggrep.lua:1-72
**Tags:** git, grep, search, snacks, util

## Scope
Thin wrapper around `git grep -n --column -I --no-color` that resolves the repo root with `git rev-parse --show-toplevel`, parses `file:line:col:text` output into picker items, and hands them to `Snacks.picker.pick` with file preview. Confirming an item jumps to the exact `(line, col)`. Three entry points cover the common cases: free-form prompt, word under cursor (`-w`), and visual selection (`-F` fixed-string).

## Install spec
Internal module — required from `lua/plugins/git.lua` keymaps:

```lua
require("util.ggrep").prompt()
require("util.ggrep").cword()
require("util.ggrep").visual()
```

## Public API
- `M.prompt()` — read a pattern via `vim.fn.input("git grep: ")` and run it as a regex. No-op on empty input.
- `M.cword()` — grep `<cword>` with `-w` (word-boundary match).
- `M.visual()` — yank the current visual selection into register `v` (saved/restored), then grep it with `-F` (fixed string, no regex escaping needed).

Internal helper (not exported):
- `run(pattern, extra_args)` — shells out to `git -C <root> grep -n --column -I --no-color [extra_args] -- <pattern>`, builds items `{ text, file, pos = {lnum, col-1}, line }`, and opens `Snacks.picker.pick({ source = "ggrep", title, items, format = "file", preview = "file", confirm = ... })`. Emits `vim.notify` warnings when not in a repo or when there are zero matches.

## Our config
Bound in `lua/plugins/git.lua`:
- `<leader>g/` (n) → `prompt()`
- `<leader>g*` (n) → `cword()`
- `<leader>g/` (v) → `visual()`

## Keymaps
The module exposes no keymaps itself; see git-fugitive.md for the bindings.

## Links
- `git grep` docs: https://git-scm.com/docs/git-grep
- Snacks picker: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md

## Notes
- `-I` skips binary files; `--no-color` is required because we parse plain `file:line:col:text` output.
- The `pos` field stores `col - 1` because `nvim_win_set_cursor` uses 0-based columns while git grep emits 1-based.
- `visual()` saves and restores register `v` so it doesn't clobber the user's clipboard/named register state.
- Only the current buffer's repo is searched (`git -C <root>`) — submodules are not recursed; pass `--recurse-submodules` via a custom `extra_args` if needed.
- Empty input from `prompt()` silently returns (guarded by `pattern == ""`) — no error notification.
- Compared to grug-far or telescope live-grep: ggrep respects `.gitignore` and submodule boundaries for free because it's literally `git grep`.
