# config-autocmds
> Global autocmds + a temporary patch for the LSP hover-shrink bug in nvim 0.12.x.

**Local file:** lua/config/autocmds.lua
**Tags:** config, autocmds, lsp, workaround

## Scope

`lua/config/autocmds.lua` registers a small set of QoL autocmds (yank highlight, last-cursor, auto-mkdir, swap-exists, resize, `]]`/`[[` word-search re-assert, close-with-q) and wraps `vim.lsp.util.open_floating_preview` to work around a Neovim 0.12.x hover-shrink bug. Each autocmd lives in its own augroup with `clear = true` so re-sourcing the file is idempotent.

## Highlights

### LSP hover shrink workaround
Wraps `vim.lsp.util.open_floating_preview` to force a redraw between window creation and the height check, then resizes the window **up** to fit content. Cited verbatim from the comment block:

> *nvim 0.12.x LSP hover float shrinks too aggressively after treesitter conceal_lines hides markdown code-fence rows.*
> *…long wrapped lines (e.g. typescript signatures) get clipped.*
> *This wrapper forces a redraw between window creation and the height check so `nvim_win_text_height` returns the true rendered row count, then resizes the window UP to fit content rather than down. Same approach as upstream PR #32662.*

Removal instructions live in the same comment: when neovim/neovim#32607, #32639, #32662 ship a fix in 0.12.x/0.13, delete the `do … end` block and verify hover on a long TypeScript signature still renders fully.

### Augroups

| Augroup | Event | Pattern | Purpose |
| --- | --- | --- | --- |
| `swap_exists` | `SwapExists` | — | Auto-pick "edit anyway" (`vim.v.swapchoice = "e"`). Snacks picker opens files non-interactively and would otherwise block on E325. |
| `highlight_yank` | `TextYankPost` | — | Flashes yanked region via `vim.hl.on_yank()`. |
| `resize_splits` | `VimResized` | — | Equalizes splits across every tab without leaving the current tab — saves tab number, `tabdo wincmd =`, restores tab. |
| `auto_create_dir` | `BufWritePre` | — | `mkdir -p` the parent dir of the file about to be written. Skips URI-style buffers (`oil://`, `term://`, …) via the `^%w%w+:[\\/][\\/]` guard. Resolves through `fs_realpath` to follow symlinks. |
| `last_cursor_position` | `BufReadPost` | — | Restore cursor to the `"` mark if it points inside the buffer. Skips `gitcommit`/`gitrebase` (stale position from the last commit) and non-file buftypes. Wrapped in `pcall` so weird buffer states never raise. |
| `universal_word_search` | `FileType` | — | Re-asserts buffer-local `]]`/`[[` word-under-cursor text-search maps after runtime ftplugins (ruby, python, rust, markdown, …) rebind them to section motions. Real file buffers only — the check runs in `vim.schedule` because `:help` sets `buftype` *after* FileType fires; qf/help/terminal/prompt keep their native `[[`/`]]`. |
| `close_with_q` | `FileType` | `help`, `qf`, `lspinfo`, `man`, `notify`, `checkhealth`, `grug-far`, `gitsigns-blame` | Maps `q` to `:close` in transient/inspect buffers and sets `buflisted = false` so they don't pollute `<S-h>/<S-l>` cycling. |

## Links

- Related [config-init](config-init.md)
- Related [config-keymaps](config-keymaps.md) — `<S-h>/<S-l>` buffer cycling that the `buflisted = false` flag interacts with.
- Upstream issues: neovim/neovim#32607, #32639, #32662.

## Notes

- The hover wrapper is a one-shot replacement of the function; it does *not* call `nvim_create_autocmd`. Re-sourcing the file replaces the wrapper with another wrapper around the now-already-wrapped function — usually harmless, but a hard restart is cleaner if you edit this block.
- `auto_create_dir` writes through `vim.uv.fs_realpath` so saving a file inside a symlinked directory still creates the real path's parent.
- If you add a new transient filetype, append it to the `close_with_q` pattern list — that's the canonical place.
