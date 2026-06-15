# git-fugitive
> Tpope's git porcelain inside Vim — `:G` for status/commit/push, `:Gedit` for revs, `:Gdiffsplit` diffs.

**Repo:** https://github.com/tpope/vim-fugitive
**Local spec:** lua/plugins/git.lua:63-87
**Tags:** git, log, diff, porcelain

## Scope
Wraps git CLI subcommands as `:Git` (alias `:G`) with a buffer-driven status UI, opens any revision as a buffer via `:Gedit <rev>`, and provides side-by-side diffs via `:Gdiffsplit`. Lazy-loaded on its commands and our `<leader>g*` keymaps; the line_history util also shells out to git directly and relies on fugitive only for the `:Gedit <sha>` confirm action.

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

Most workflows are driven by these commands instead: `:G` (status), `:G commit`, `:G push`, `:G log`, `:Gdiffsplit`, `:Gedit <rev>`, `:Gread <rev>:%`, `:Gclog`, `:GBrowse` (via vim-rhubarb).

## Our config
No setup call — fugitive is loaded by the commands and the keymaps below. `<leader>gl`/`<leader>gf` delegate to the `line_history` util, which builds a snacks picker over `git log` output and opens the chosen commit read-only with `:Gedit` (never checks out).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>gl` | n | `require("util.line_history").pick()` | Line history (commits touching current line) |
| `<leader>gl` | v | `util.line_history.pick(s, e)` | Range history (visual selection) |
| `<leader>gf` | n | `require("util.line_history").file()` | File history (commits touching current file) |
| `<leader>gd` | n | `:Gdiffsplit` | Diff current file vs index (side-by-side) |

Inside `:G` status: `s`/`u` stage/unstage, `=` toggle diff, `cc` commit, `dd` `:Gdiffsplit`, `<CR>` open file.
Inside `:Gdiffsplit`: `]c`/`[c` next/prev change, `do`/`dp` diff get/put, `:diffupdate` refresh.

## Links
- README: https://github.com/tpope/vim-fugitive/blob/master/README.markdown
- `:help fugitive` — full reference.
- `:help fugitive-maps` — buffer-local mappings inside fugitive UIs.

## Notes
- `:Gedit <sha>` is used by `util.line_history` to open a historical commit as a read-only buffer — preserves syntax/filetype unlike `git show`, and crucially does **not** check the commit out.
- `util.line_history` is the only util relying on fugitive's `:Gedit <sha>` confirm action.
- `:GBrowse` (permalink to forge) requires vim-rhubarb (GitHub); not installed here.
- Blame keymaps were removed (`<leader>gb`/`<leader>gB` no longer exist) — use `<leader>gl` for per-line commit history instead.
