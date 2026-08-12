# workflow-replace
> Find-and-replace with regex: one buffer, a reviewed project-wide diff, a quickfix list, or a rename that understands the language.

**Repo:** (this config) local: ~/.config/nvim
**Local spec:** lua/plugins/editor.lua:102-116; lua/config/keymaps.lua:49, 144-153; lua/config/rename.lua
**Tags:** replace substitute regex grug-far cdo rename refactor workflow

## Scope
Four replace backends, ordered by blast radius. Pick by *how much you need to review*, not by
habit. Finding the matches first is [workflow-search](workflow-search.md); the list plumbing is
[workflow-quickfix](workflow-quickfix.md).

| Reach | Tool | Review model |
|---|---|---|
| Current buffer | `:s` | live preview via `inccommand=split` |
| Project-wide, text | `<leader>sr` grug-far | editable result buffer, replace when happy |
| Exactly the entries you curated | `<leader>xr` (`:cdo`) | you filtered the qf list first |
| One symbol, semantically | `<leader>cr` | LSP knows the scope; no pattern at all |
| A handful of visible spots | `<leader>cm` multicursor | you watch it happen |

## 1. `:substitute` — the current buffer
`inccommand=split` is set, so every `:s` shows a live preview in a split before you hit `<CR>`.

```vim
:%s/old/new/g            " whole file, every occurrence
:%s/old/new/gc           " …ask per match (y/n/a/q/l)
:'<,'>s/old/new/g        " visual range
:.,+10s/old/new/g        " this line + 10
:%s/old/new/gie          " i=ignore case, e=no error when nothing matches
:%s//new/g               " empty pattern = reuse the last search (/ or *)
```

Vim regex, not PCRE. Prefix `\v` (very magic) and it stops looking like line noise:
```vim
:%s/\v<(get|set)(\w+)>/\1_\2/g       " \1 \2 = capture groups
:%s/\v(\d{4})-(\d{2})-(\d{2})/\3\/\2\/\1/g
:%s/\vfoo/\=luaeval('…')/g           " \= evaluates an expression as the replacement
:%s/\vfoo/\U&/g                      " \U…\E upper-cases; & = the whole match
```
Scope tricks that beat re-typing a range:
- `\%V` — only inside the last visual selection: `:%s/\%Vfoo/bar/g` (select, `:`, then edit).
- `\zs` / `\ze` — set match start/end: `:%s/user\zsId/_id/` only rewrites `Id`.
- `\%>20l\%<40l` — line-range atoms inside the pattern itself.
- `&` repeats the last `:s` on this line, `:&&` repeats it *with the flags*, `g&` repeats it
  across the whole file with the last search pattern.

## 2. grug-far — project-wide, reviewed
`<leader>sr` opens the buffer; `<leader>sR` prefills the word under cursor (`x` mode: the
visual selection). It is a form — `<Tab>`/`<S-Tab>` walk the fields:

| Field | Takes | Example |
|---|---|---|
| **Search** | rg regex (Rust syntax) | `fun\(([a-z0-9]*)\)` |
| **Replace** | `$1` / `${1}` refs, `$$` for a literal `$` | `${1}_foo` |
| **Files Filter** | rg globs, **one per line** | `*.php` / `**/docs/*.md` / `*.{css,js}` |
| **Flags** | raw rg flags | `-i` `--multiline` (`-U`) `--fixed-strings` `-P` |
| **Paths** | dirs/files to limit the run | `./src2` `~/.config` |

Buffer keymaps (localleader is `\`):

| Key | Action |
|---|---|
| `\r` | Replace all — the real write |
| `\s` | Sync all shown lines back into the files (edit results first, then sync) |
| `\l` / `\v` | Sync just this line / this file |
| `\q` | **Send results to the quickfix list** → hand off to [workflow-quickfix](workflow-quickfix.md) |
| `\o` / `\i` / `<enter>` | Open / preview / jump to the match under cursor |
| `\e` | Swap engine: ripgrep ↔ ast-grep (structural, `$A`/`$$$ARGS` metavariables) |
| `\x` | Swap replacement interpreter to Lua or Vimscript — the replacement becomes a function body with `match` in scope |
| `\w` | Show the exact rg command being run (best debugging tool in the buffer) |
| `\t` / `\a` | Open history / add current search to history |
| `\b` | Abort a running search |
| `g?` | Help |

The Lua interpreter (`\x`) is the escape hatch when a regex can't express the replacement:
```lua
if vim.startswith(match, "use") then return "employ" .. match else return match end
```

## 3. `:cdo` — replace across a curated list
When the set of places is easier to *select* than to *describe*: grep → `<C-q>` → `:Cfilter`
the noise out → `<leader>xr`.

`<leader>xr` prompts `cdo s/` and you type the rest, then it runs `:cdo s/<input> | update`.
```
old/new/g          →  :cdo s/old/new/g | update
\vold(\w+)/new\1/ge  →  very-magic + capture, e = skip entries with no match
```
Add the `e` flag whenever the list came from a *different* pattern than the one you're
substituting — otherwise the first non-matching entry aborts the run with `E486`.
`:cfdo %s/…/ge | update` is the per-file variant: fewer passes, and `%` covers matches the
grep never listed.

## 4. `<leader>cr` — rename, not replace
Context-smart (`lua/config/rename.lua`): CSS class → tag pair → LSP symbol, in that order.
No pattern, no false positives in strings or comments, cross-file when the LSP says so.
Reach for it first on identifiers; drop to grug-far only when the rename is repo-wide or the
LSP can't see the other side. PHP variables go through a raw `textDocument/rename` request
(`$` sigil handling — see [ftplugin-php](ftplugin-php.md)).

CSS class rename is deliberately component-scoped; repo-wide class renames go through
grug-far where the diff is reviewable.

## 5. Multicursor — replace by typing
`<leader>cm` puts a cursor on every match of the word under cursor (`<leader>cn`/`<leader>cN`
add them one at a time, `<leader>cS` skips one). Then `ciw` + type once. Best under ~20
occurrences in one screenful, where seeing the edits beats writing a pattern.
See [editor-multicursor](editor-multicursor.md).

## Notes
- Search regex and replace regex are **different dialects** when you cross tools: rg/grug-far
  use Rust regex + `$1`; `:s` uses vim regex + `\1`. The translation table lives in
  [workflow-search](workflow-search.md).
- rg (so grug-far too) has **no lookaround or backreferences** without `-P` in Flags.
- `ignorecase` + `smartcase` are on, so `/foo` is case-insensitive and `/Foo` is not. In `:s`
  that same rule applies — force with `\c` / `\C` in the pattern when it matters.
- grug-far's `\r` writes files directly with no undo point in *your* buffers. `\q` → quickfix
  → `<leader>xr` is the slower path that leaves everything reviewable and undoable per file.
- `:s` on a huge range with `inccommand=split` can lag; `:set inccommand=` disables preview
  for the session.

## Links
- Related: [workflow-search](workflow-search.md), [workflow-quickfix](workflow-quickfix.md),
  [editor-grug-far](editor-grug-far.md), [editor-multicursor](editor-multicursor.md),
  [config-rename](config-rename.md)
- `:help :substitute`, `:help pattern-overview`, `:help sub-replace-special`, `:help :cdo`
