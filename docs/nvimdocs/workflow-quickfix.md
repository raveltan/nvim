# workflow-quickfix
> The quickfix list as a work queue: how to fill it, walk it, filter it, edit it, and run a command over every entry.

**Repo:** (this config) local: ~/.config/nvim
**Local spec:** lua/config/keymaps.lua:129-157, 212-221; lua/plugins/editor.lua:450-464
**Tags:** quickfix loclist cdo cfdo quicker refactor workflow

## Scope
Quickfix is a list of `file:line:col:text` entries plus a cursor into it. Anything that can
produce that shape can fill it, and a handful of commands operate on the whole list at once —
which is what turns "grep for 40 hits" into "edit 40 hits". This doc is the full pipeline;
[workflow-search](workflow-search.md) is what feeds it.

Quickfix is **global** (one per tab-stack, with a 10-deep history). The **location list** is
the same machinery scoped to one window — use it when you want a second list that doesn't
clobber the first. Every `c*` command below has an `l*` twin (`:lgrep`, `:ldo`, `:lfdo`, `:Lfilter`).

## 1. Fill it
| Source | How |
|---|---|
| Any snacks picker | `<C-q>` — sends **all** results, or just the `<Tab>`-selected ones |
| grug-far buffer | `<localleader>q` (localleader is `\`) |
| Diagnostics (whole project) | `<leader>xd` → `vim.diagnostic.setqflist()` |
| TODO/FIX/HACK comments | `<leader>xt` → `:TodoQuickFix` |
| Merge conflicts | `<leader>gcq` → `:GitConflictListQf` |
| phpstan / larastan (whole project) | `:LaravelPhpstan` ([laravel-tooling](laravel-tooling.md)) |
| Cmdline grep | `:grep pat` (rg), `:vimgrep /pat/gj **/*.lua` (vim regex) |
| Current file only | `:vimgrep /pat/gj %` |
| LSP | `vim.lsp.buf.references()` / nvim's native handlers when >1 result |
| Compiler / test output | `:cexpr system('…')`, `:cgetbuffer`, `:cfile <errorfile>` |
| Arbitrary lines | `:cexpr` / `:caddexpr` with `file:line:col:msg` strings |

The `:g` + `:caddexpr` idiom builds a list from *anything* vim can match in the current file
— useful when the pattern is easier to express in vim regex than in rg:
```vim
:cexpr []
:g/\v^\s*function\s+get\w+/caddexpr expand('%') . ':' . line('.') . ':' . getline('.')
:copen
```

## 2. Walk it
| Key / cmd | Action |
|---|---|
| `<leader>xq` | Toggle the quickfix window ([editor-quicker](editor-quicker.md)) |
| `]q` / `[q` | Next / prev entry, **wraps** at the ends, recentres (`zz`) |
| `]Q` / `[Q` | Last / first entry |
| `<leader>xl` | Toggle the location list |
| `<leader>xx` | Same diagnostics, in [Trouble](lsp-trouble.md) instead |
| `:cc 12` | Jump to entry 12 |
| `:cnf` / `:cpf` | First entry of the next / previous **file** |
| `:colder` / `:cnewer` | Previous / next quickfix list — 10 are kept, so a fresh grep never destroys the old one |

`]q`/`[q` wrap deliberately (`cnext` → falls back to `cfirst`), so holding `]q` cycles the
list forever instead of erroring at the end.

## 3. Read it
Inside the qf window ([quicker.nvim](editor-quicker.md)):
- `>` — expand 2 lines of context around every entry (additive; press again for more).
- `<` — collapse back to just the matches.
- Entries are treesitter- and LSP-highlighted, so the list reads like source, not like a log.

## 4. Filter it
`:Cfilter` keeps/removes entries by pattern — the fastest way to drop `vendor/`, tests, or a
noisy match without re-running the search. It ships with nvim but is an opt-in package:
```vim
:packadd cfilter        " once per session
:Cfilter /Controller/   " keep only entries matching (pattern OR filename)
:Cfilter! /Test/        " remove matching entries
:Lfilter /…/            " same, for the location list
```
Each `:Cfilter` pushes a **new** list, so `:colder` undoes it.

## 5. Edit it — two different tools
**Direct edit (quicker.nvim).** The qf buffer is modifiable. Change the text of an entry,
`:w`, and the edit is written back to the real file. Delete a line and it leaves the list.
This is the right tool for 5–20 hand-judged edits — you see every line in context, and you
can skip the ones that shouldn't change.

**Run a command over every entry.**
| Cmd | Runs |
|---|---|
| `:cdo {cmd}` | once per **entry** |
| `:cfdo {cmd}` | once per **file** in the list |
| `:ldo` / `:lfdo` | loclist twins |

`<leader>xr` wraps the common case: it prompts `cdo s/`, then runs
`:cdo s/<your input> | update` — refuses to run on an empty list, and `pcall`s so one entry
with zero matches doesn't abort the rest. Type the *rest* of the substitute, e.g.
`old/new/g`. Details and pattern syntax: [workflow-replace](workflow-replace.md).

Other things worth `:cfdo`-ing:
```vim
:cfdo %s/\<Foo\>/Bar/ge | update      " project rename, one pass per file
:cfdo normal! gg=G | update           " reindent every touched file
:cfdo lua vim.lsp.buf.format() | update
:cdo normal! A;                       " append to every matched line
```
`| update` writes only modified buffers; without it you end up with dozens of unsaved
buffers (and `:cfdo` aborts on `E37` unless `hidden` is set — it is, by default in nvim).

## 6. Scripting it
```lua
vim.fn.getqflist()                       -- entries: { bufnr, lnum, col, text, valid, … }
vim.fn.getqflist({ size = 0 }).size      -- cheap emptiness check (what <leader>xr uses)
vim.fn.getqflist({ title = 0 }).title    -- which search produced this list
vim.fn.setqflist({}, 'r', { title = 'phpstan', items = items })  -- replace current list
vim.fn.setqflist({}, ' ', { … })         -- push a NEW list (keeps history)
vim.diagnostic.setqflist({ severity = vim.diagnostic.severity.ERROR })
```
`lua/artisan/lint.lua:253` is the in-repo example of building `items` by hand.

## Canonical flows
```
<leader>sg  pattern -- -g '*.php'   →  <C-q>  →  :packadd cfilter | :Cfilter! /Test/  →  <leader>xr  old/new/g
<leader>xd  (diagnostics)           →  ]q ]q ]q, fix in place        →  <leader>xd again to refresh
<leader>sw  (word under cursor)     →  <C-q>  →  <leader>xq, edit lines directly, :w
:vimgrep /pat/gj %                  →  <leader>xq, `>` for context, delete the rows to skip, :w
```

## Notes
- `<leader>x` is the `diagnostics/quickfix` which-key group. While multicursor is active it
  is temporarily `deleteCursor` (layer-scoped, `lua/plugins/editor.lua:523`) — no permanent clash.
- quicker's `:w` writes through to files with no confirmation. `:colder` does not undo it —
  plain `u` in each file does.
- `:cdo` moves the cursor through every entry; wrap in `:noautocmd` if a heavy `BufEnter`
  autocmd makes it crawl.
- A `:cdo s/…/` with no `e` flag stops at the first entry that doesn't match (`E486`).
  `<leader>xr` does not add `e` for you — type it.
- nvim-bqf was removed; quicker is the sole quickfix enhancer.

## Links
- Related: [workflow-search](workflow-search.md), [workflow-replace](workflow-replace.md),
  [editor-quicker](editor-quicker.md), [lsp-trouble](lsp-trouble.md), [snacks-picker](snacks-picker.md)
- `:help quickfix`, `:help :cdo`, `:help :Cfilter`, `:help setqflist()`
