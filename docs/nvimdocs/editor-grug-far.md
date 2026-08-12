# editor-grug-far
> Buffer-based project-wide find-and-replace with live preview powered by ripgrep.

**Repo:** https://github.com/MagicDuck/grug-far.nvim
**Local spec:** lua/plugins/editor.lua:108
**Tags:** search, replace, ripgrep, refactor

## Scope
Opens a dedicated buffer where the search pattern, replacement, file globs, and flags are editable text fields. Results stream in as you type and can be modified in-place before applying. Backed by ripgrep; no external picker required.

## Install spec
```lua
{
  "MagicDuck/grug-far.nvim",
  cmd = "GrugFar",
  keys = { ... },
  config = true,
}
```

## Common customizations
- `engine` *(string, "ripgrep")* — search engine: `ripgrep` or `astgrep`.
- `engines.ripgrep.path` *(string, "rg")* — rg binary path.
- `engines.ripgrep.extraArgs` *(string, "")* — extra args appended to every search.
- `windowCreationCommand` *(string, "top split")* — how the buffer is opened.
- `transient` *(bool, false)* — close buffer after replace.
- `staticTitle` *(string, "Grug FAR")* — buffer name/title.
- `startInInsertMode` *(bool, true)* — focus search field in insert mode.
- `wrap` *(bool, true)* — wrap result lines.
- `prefills` *(table)* — pre-fill `search`, `replacement`, `filesFilter`, `flags`, `paths`.
- `icons.enabled` *(bool, true)* — show field icons (requires nerd font).
- `keymaps` *(table)* — buffer-local keymaps; see upstream for all action names.

## Our config
Defaults via `config = true`. Three launcher keymaps (below).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>sr` | n | `require("grug-far").open()` | Open empty grug-far |
| `<leader>sR` | n | open with `prefills.search = <cword>` | Search word under cursor |
| `<leader>sR` | x | `require("grug-far").with_visual_selection()` | Search visual selection |

Inside the grug-far buffer (upstream defaults; localleader is `\`):

| Key | Action |
|---|---|
| `<tab>` / `<s-tab>` | Next / prev input field |
| `\r` | Replace all (the real write) |
| `\s` | Sync all shown result lines back into the files |
| `\l` / `\v` | Sync just this line / this file |
| `\q` | **Send results to the quickfix list** |
| `\o` / `\i` / `<enter>` | Open / preview / jump to the match under cursor |
| `<down>` / `<up>` | Open next / prev location |
| `\e` | Swap engine: ripgrep ↔ ast-grep |
| `\x` | Swap replacement interpreter (Lua / Vimscript function body, `match` in scope) |
| `\w` | Toggle "show the rg command being run" |
| `\t` / `\a` | Open history / add current search to history |
| `\b` | Abort a running search |
| `\c` | Close |
| `g?` | Help |

### Fields
| Field | Takes |
|---|---|
| Search | rg regex (Rust syntax) — `fun\(([a-z0-9]*)\)` |
| Replace | `$1` / `${1}` captures, `$$` for a literal `$` |
| Files Filter | rg globs, **one per line** — `*.php`, `**/docs/*.md`, `*.{css,js}` |
| Flags | raw rg flags — `-i`, `--multiline` (`-U`), `--fixed-strings`, `-P` |
| Paths | dirs/files to limit the run |

## Links
- README: https://github.com/MagicDuck/grug-far.nvim/blob/main/README.md
- Options: https://github.com/MagicDuck/grug-far.nvim/blob/main/lua/grug-far/opts.lua
- Related: [workflow-replace](workflow-replace.md) (all four replace backends compared), [workflow-quickfix](workflow-quickfix.md) (`\q` hand-off)

## Notes
- `<leader>sR` is mapped in both `n` and `x`; lazy.nvim picks the right one by mode.
- Supports `--multiline` rg flag for multiline search/replace when set in the `Flags:` field.
- rg has **no lookaround or backreferences** unless you add `-P` (PCRE2) to Flags.
- `\r` writes files directly, with no undo point in your open buffers. `\q` → quickfix →
  `<leader>xr` is the slower path that stays reviewable and undoable per file.
