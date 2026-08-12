# workflow-search
> How to find things in this config: files, text, regex, scoped to certain filetypes/dirs, and in-buffer.

**Repo:** (this config) local: ~/.config/nvim
**Local spec:** lua/plugins/snacks.lua:189-232, lua/plugins/fff.lua:7-18, lua/config/keymaps.lua:229-236
**Tags:** search grep ripgrep regex picker workflow

## Scope
The "find" half of the find → quickfix → replace pipeline. Covers which picker owns which
motion, the two different query languages (fuzzy matcher vs ripgrep regex), how to scope a
search to certain files, and in-buffer search. Sends results onward via
[workflow-quickfix](workflow-quickfix.md); rewrites them via [workflow-replace](workflow-replace.md).

## Who owns what
| Motion | Key | Owner | Why |
|---|---|---|---|
| Find file | `<leader><leader>` | [nav-fff](nav-fff.md) | Rust binary + frecency; fastest open-by-name |
| Recent / projects / buffers | `<leader>fr` `<leader>fp` `<leader>,` | [snacks-picker](snacks-picker.md) | |
| Grep workspace | `<leader>sg` | snacks.picker | async rg, streams the **full** result set |
| Grep word / selection | `<leader>sw` (n, x) | snacks.picker | `rg --word-regexp`, literal (not regex) |
| Grep current file's dir | `<leader>s.` | snacks.picker | `dirs = { %:p:h }` |
| Fuzzy grep | `<leader>sz` | fff.nvim | frecency-ordered, **partial** on big repos |
| Find + replace UI | `<leader>sr` / `<leader>sR` | [editor-grug-far](editor-grug-far.md) | see workflow-replace |
| Symbols | `<leader>ss` / `<leader>sS` | snacks.picker (LSP) | |
| TODO/FIXME | `<leader>st` | todo-comments | |

`<leader>sz` is deliberately the odd one out: fff's grep is synchronous per keystroke with a
200 ms budget, so on a big repo it only ever reaches the highest-frecency files. Use it to
re-find something you touched recently, never to prove a string is absent.

## Two query languages — know which one you are typing into
**Live rg mode** (`<leader>sg`, `<leader>s.`): what you type is a **ripgrep regex**, sent to
`rg --smart-case --column`. Rust regex syntax: `\b`, `\d`, `(a|b)`, `{2,}`, `[^x]` all work;
**backreferences and lookaround do not** (add `-P` for PCRE2 if you need them).

**Fuzzy matcher mode** (`<leader>sw`, file lists, and any live picker after `<C-g>`): fzf
syntax over already-fetched results —

| Pattern | Meaning |
|---|---|
| `foo bar` | fuzzy, all terms must match (AND) |
| `'foo` | exact substring |
| `'foo'` | exact word |
| `^foo` / `foo$` | prefix / suffix anchor |
| `!foo` | negate |
| `file:lua$ 'function` | field-scoped: path ends in `lua` AND text contains `function` |

`<C-g>` toggles live ↔ fuzzy inside the picker, so the normal flow is: type a loose rg regex
to get the candidate set, `<C-g>`, then narrow with `!test` / `file:php$`.

## Scoping to certain files
Three ways, in order of how often they're worth using:

1. **Inline rg args after ` -- `** — the picker splits the query on a bare `--` and passes
   the tail to ripgrep verbatim:
   ```
   handleRequest -- -g '*.php' -g '!*Test.php'
   getUser -- -t php
   TODO -- -g 'src/**/*.ts' --hidden
   assertEquals -- -U --multiline-dotall
   ```
   `-t <type>` is a named filetype bundle (`rg --type-list` for the catalogue), `-g` is a
   glob, `-g '!…'` excludes, `-U` enables multiline matching.
2. **Toggles inside the picker** — `<a-h>` hidden files, `<a-i>` gitignored files, `<a-f>`
   follow symlinks, `<a-r>` regex ↔ literal (`--fixed-strings`).
3. **A dedicated keymap** when you do it constantly — `Snacks.picker.grep({ ft = "php" })`,
   `{ glob = "**/*.blade.php" }`, `{ dirs = { "src2" } }`, `{ buffers = true }`, or
   `{ args = { "-P" } }`. `lua/plugins/docs.lua:171-282` is the worked example (per-docset
   greps with a fixed `cwd`).

## In the same file
| Want | Do |
|---|---|
| Next/prev occurrence of word under cursor | `]]` / `[[` (plain text search, no LSP — `util.wordsearch`) |
| Search with a live match counter | `/pat` — [editor-hlslens](editor-hlslens.md) shows `n/total`, `n`/`N` recentre with `zzzv` |
| Grep only this file, into a list | `:vimgrep /pat/gj %` → [quickfix](workflow-quickfix.md), or `:lvimgrep /pat/gj %` → loclist |
| Grep only open buffers | `Snacks.picker.grep_buffers()` |
| Jump to a visible spot | `s` / `S` ([editor-flash](editor-flash.md)) |
| Every match as a cursor | `<leader>cm` ([editor-multicursor](editor-multicursor.md)) |

## Vim regex vs ripgrep regex
The two halves of the pipeline do **not** share a syntax. Grep with rg, then substitute with
vim's own regex — the pattern usually needs translating:

| Meaning | ripgrep (rg) | vim (`:s`, `/`, `:vimgrep`) |
|---|---|---|
| Word boundary | `\bfoo\b` | `\<foo\>` |
| Group + alternation | `(a\|b)` | `\(a\|b\)` or `\v(a\|b)` |
| One-or-more | `a+` | `a\+` or `\va+` |
| Capture reference | `$1` (in replacement) | `\1` |
| Case-insensitive | `-i` (or smart-case default) | `\cpat` |
| Match only part | n/a | `\zsfoo\ze` |
| Restrict to selection | n/a | `\%Vfoo` |

Prefix vim patterns with `\v` (very magic) to get near-PCRE behaviour: `\v(get|set)(\w+)`.

## `:grep` and `:vimgrep` from the cmdline
Nvim 0.12 already sets `grepprg=rg --vimgrep -uu` when ripgrep is on `$PATH` — no config
needed, and `:grep` lands straight in the quickfix list.

```vim
:grep -t php 'class \w+Repository'   " rg flags pass straight through
:grep -g '!vendor/*' TODO
:vimgrep /\<TODO\>/gj **/*.lua       " vim regex; g=every match on a line, j=don't jump
:lgrep …                             " same, into the loclist instead
```

Gotcha: that default `-uu` means **`.gitignore` is ignored and hidden files are searched** —
`:grep` will happily return hits from `node_modules/` and `vendor/` that `<leader>sg` hides.
Add `-g '!vendor/*'` or use the picker when that matters.

## Notes
- `<a-…>` toggles need the terminal to send Alt. `macos-option-as-alt` is **not** set in
  `~/.config/ghostty/config` today, so if `<a-h>` does nothing that is why.
- `<leader>sw` is `regex = false` + `--word-regexp`: it matches the word literally, so
  searching a symbol with `$` or `::` in it works without escaping.
- Grep pickers use the `ivy` layout (bottom dock, full-width preview) on purpose — a match
  is only readable with its surrounding lines. See [snacks-picker](snacks-picker.md).
- No picker result is a dead end: `<C-q>` sends the whole list to quickfix. That is where
  [workflow-quickfix](workflow-quickfix.md) picks up.

## Links
- Related: [workflow-quickfix](workflow-quickfix.md), [workflow-replace](workflow-replace.md),
  [snacks-picker](snacks-picker.md), [nav-fff](nav-fff.md), [editor-grug-far](editor-grug-far.md)
- `:help pattern` (vim regex), `rg --help`, https://docs.rs/regex (rg's syntax)
