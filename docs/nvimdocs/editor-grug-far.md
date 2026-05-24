# editor-grug-far
> Buffer-based project-wide find-and-replace with live preview powered by ripgrep.

**Repo:** https://github.com/MagicDuck/grug-far.nvim
**Local spec:** lua/plugins/editor.lua:65-73
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

Inside the grug-far buffer (defaults):
- `<localleader>r` — replace all
- `<localleader>s` — sync line into file
- `<localleader>x` — open result in editor
- `q` or `<localleader>c` — close

## Links
- README: https://github.com/MagicDuck/grug-far.nvim/blob/main/README.md
- Options: https://github.com/MagicDuck/grug-far.nvim/blob/main/lua/grug-far/opts.lua

## Notes
- `<leader>sR` is mapped in both `n` and `x`; lazy.nvim picks the right one by mode.
- Supports `--multiline` rg flag for multiline search/replace when set in the `Flags:` field.
