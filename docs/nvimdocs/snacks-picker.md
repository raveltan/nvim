# snacks-picker
> Modern fuzzy-finder — our primary file/grep/LSP/git picker.

**Repo:** https://github.com/folke/snacks.nvim
**Local spec:** lua/plugins/snacks.lua:3, 97-122
**Tags:** snacks picker fuzzy-finder telescope-alternative lsp git

## Scope
`Snacks.picker` is a fzf-syntax fuzzy finder with 40+ built-in sources, async matching, treesitter-highlighted previews, and presets (default/vertical/ivy/sidebar/vscode). It also installs as the `vim.ui.select` backend. Our config customises only the `projects` source — all other sources use defaults — and registers ~20 keymaps across find/search/LSP/git/history namespaces.

## Install spec
```lua
picker = {
  enabled = true,
  sources = {
    projects = {
      dev = vim.list_extend(
        vim.g.gaf and { "~/freelancer-dev" } or {},
        { "~/repo", "~/rails" }
      ),
      patterns = { ".git", "Gemfile", "composer.json", "pyproject.toml",
                   "requirements.txt", "Pipfile", "setup.py", "package.json" },
    },
  },
},
```

## Common customizations
Top-level picker options (per `docs/picker.md`):

- `live` / `limit_live` *(bool/int)* — live search mode + result cap.
- `matcher` *(table)* — `smartcase`, `ignorecase`, `frecency`, `cwd_bonus` weights for ranking.
- `layout` *(string|table)* — preset (`default`, `vertical`, `ivy`, `sidebar`, `vscode`) or full window spec.
- `focus` *("input"|"list")* — initial focus location.
- `auto_close` *(bool)* — close picker on focus loss.
- `ui_select` *(bool, true)* — replace `vim.ui.select`.
- `toggles` *(table)* — keys for hidden/ignored/regex toggles in-picker.
- `sources.<name>` *(table)* — per-source overrides. Each source accepts `cwd`, `pattern`, `hidden`, `ignored`, custom `cmd`, `format`, `actions`.

### `projects` source options used here
- `dev` *(string[])* — root directories that contain many projects; each subdirectory becomes a project entry.
- `patterns` *(string[])* — files/dirs that mark a project root.
- `recent` *(bool, true)* — also include directories of recent files.
- `max_depth` *(int, 2)* — how deep to walk under each `dev` entry.

## Built-in sources we use
- **Files**: `files`, `recent`, `buffers`, `projects`, `lines`.
- **Search**: `grep`, `help`, `commands`, `keymaps`, `diagnostics`, `resume`.
- **LSP**: `lsp_symbols`, `lsp_workspace_symbols`, `lsp_definitions`, `lsp_references`, `lsp_implementations`, `lsp_type_definitions`.
- **Git**: `git_log` (we don't use git_status/branches — handled by [git-fugitive](git-fugitive.md) / [lazygit](snacks-misc.md)).
- **History**: `registers`, `marks`, `jumps`, `search_history`, `command_history`.

## Our config
- `projects.dev` includes `~/repo` and `~/rails` always; **`~/freelancer-dev` is prepended only when `vim.g.gaf == true`** (i.e. nvim was started with `GAF=1`).
- `projects.patterns` adds Ruby/PHP/Python/Node markers on top of the default `.git`, so polyglot monorepos resolve correctly.
- No `layout` override — uses the default split preset.
- `vim.ui.select` integration is on by default (we don't disable it).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>fr` | n | `Snacks.picker.recent()` | Recent files |
| `<leader>fp` | n | `Snacks.picker.projects()` | Projects |
| `<leader>,` | n | `Snacks.picker.buffers()` | Buffers |
| `<leader>sb` | n | `Snacks.picker.lines()` | Buffer lines |
| `<leader>sh` | n | `Snacks.picker.help()` | Help pages |
| `<leader>sk` | n | `Snacks.picker.keymaps()` | Keymaps |
| `<leader>sc` | n | `Snacks.picker.commands()` | Commands |
| `<leader>sd` | n | `Snacks.picker.diagnostics()` | Diagnostics |
| `<leader>sR` | n | `Snacks.picker.resume()` | Resume last picker |
| `<leader>ss` | n | `Snacks.picker.lsp_symbols()` | Document symbols |
| `<leader>sS` | n | `Snacks.picker.lsp_workspace_symbols()` | Workspace symbols |
| `gd` | n | `Snacks.picker.lsp_definitions()` | Go to definition |
| `gr` | n | `Snacks.picker.lsp_references()` | References |
| `gI` | n | `Snacks.picker.lsp_implementations()` | Implementations |
| `gy` | n | `Snacks.picker.lsp_type_definitions()` | Type definitions |
| `<leader>s"` | n | `Snacks.picker.registers()` | Registers |
| `<leader>sm` | n | `Snacks.picker.marks()` | Marks |
| `<leader>sj` | n | `Snacks.picker.jumps()` | Jumplist |
| `<leader>s/` | n | `Snacks.picker.search_history()` | Search history |
| `<leader>s::` | n | `Snacks.picker.command_history()` | Command history |

## GAF integration
`projects.dev` is built with `vim.list_extend(vim.g.gaf and { "~/freelancer-dev" } or {}, { "~/repo", "~/rails" })` — so the Freelancer monorepo only appears in `<leader>fp` when running under the GAF profile (`GAF=1 nvim`). See auto-memory `nvim_gaf_profile.md`.

## Links
- README: https://github.com/folke/snacks.nvim
- Picker docs: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
- Related: [snacks-core](snacks-core.md), [snacks-dashboard](snacks-dashboard.md) (projects section reuses this source), [git-fugitive](git-fugitive.md), [editor-which-key](editor-which-key.md)

## Notes
- `Snacks.picker.files` is **not** bound — file search is handled by another plugin in our setup; this picker spec deliberately omits `<leader>ff`.
- `lsp_*` pickers replace nvim's default `vim.lsp.buf.*` handlers because they're bound to `gd`/`gr`/etc. directly here.
- Buffer-lines (`<leader>sb`) is the in-buffer equivalent of `:%s` preview — not a project grep.
