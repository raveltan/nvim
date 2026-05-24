# git-fugitive
> Tpope's git porcelain inside Vim — `:G` for status/commit/push, `:Gedit` for revs, interactive blame.

**Repo:** https://github.com/tpope/vim-fugitive
**Local spec:** lua/plugins/git.lua:79-105
**Tags:** git, blame, log, porcelain

## Scope
Wraps git CLI subcommands as `:Git` (alias `:G`) with a buffer-driven status UI, opens any revision as a buffer via `:Gedit <rev>`, and provides the canonical interactive `:Git blame` buffer with one-key reblame and commit navigation. Lazy-loaded on its commands and our `<leader>g*` keymaps; the ggrep and line_history utils also shell out to git directly and rely on fugitive only for the `:Gedit <sha>` confirm action.

## Install spec
```lua
{
  "tpope/vim-fugitive",
  cmd = { "Git", "G", "Gclog", "Gdiffsplit", "Gedit", "Gread", "Gwrite", "Ggrep" },
  keys = { ... },
}
```

## Common customizations
Fugitive is mostly configured via `:G` subcommands rather than a setup table. Knobs that exist as globals:

- `g:fugitive_legacy_commands` *(0/1, 0)* — re-enable the old `:Gstatus`/`:Gcommit`/etc. aliases.
- `g:fugitive_no_maps` *(0/1, 0)* — suppress fugitive's default buffer mappings.
- `g:fugitive_pty` *(0/1, 1 on Unix)* — run git under a pty for colour/prompts.
- `g:fugitive_git_executable` *(string, "git")* — alternative git binary.
- `g:fugitive_dynamic_colors` *(0/1, 1)* — translate git's ANSI colours to Vim highlights.

Most workflows are driven by these commands instead: `:G` (status), `:G commit`, `:G push`, `:G blame`, `:G log`, `:Gdiffsplit`, `:Gedit <rev>`, `:Gread <rev>:%`, `:Gclog`, `:GBrowse` (via vim-rhubarb).

## Our config
No setup call — fugitive is loaded by the commands and the keymaps below. `<leader>gl` and `<leader>g/` delegate to util modules (line_history, ggrep) that prefer the snacks picker over fugitive's quickfix-based output.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>gl` | n | `require("util.line_history").pick()` | Line history (current line) |
| `<leader>gl` | v | `util.line_history.pick(s, e)` | Range history (visual selection) |
| `<leader>gB` | n | `:Git blame` | Interactive blame buffer |
| `<leader>g/` | n | `require("util.ggrep").prompt()` | Git grep (prompt) |
| `<leader>g*` | n | `require("util.ggrep").cword()` | Git grep word under cursor |
| `<leader>g/` | v | `require("util.ggrep").visual()` | Git grep visual selection |

Inside `:Git blame`: `<CR>` reblame at commit, `o`/`O` open commit in split/tab, `-` reblame parent, `~` reblame Nth ancestor, `q` close.
Inside `:G` status: `s`/`u` stage/unstage, `=` toggle diff, `cc` commit, `dd` `:Gdiffsplit`, `<CR>` open file.

## Links
- README: https://github.com/tpope/vim-fugitive/blob/master/README.markdown
- `:help fugitive` — full reference.
- `:help fugitive-maps` — buffer-local mappings inside fugitive UIs.

## Notes
- `<leader>gb` (gitsigns blame pane) and `<leader>gB` (fugitive interactive blame) are intentionally distinct: gitsigns shows an author column you can scroll; fugitive opens a navigable blame buffer where `<CR>` walks commit history.
- `:Gedit <sha>` is used by `util.line_history` to open a historical revision of a file as a read-only buffer — preserves syntax/filetype unlike `git show`.
- `:GBrowse` (permalink to forge) requires vim-rhubarb (GitHub) or tpope/vim-rhubarb-equivalents; not installed here.
- Avoid `:Ggrep` directly — `<leader>g/` uses our snacks-picker wrapper which is faster and has live preview.
