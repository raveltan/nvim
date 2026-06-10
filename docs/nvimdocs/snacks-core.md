# snacks-core
> Overview of folke/snacks.nvim — the QoL meta-plugin, which modules we enable, and why.

**Repo:** https://github.com/folke/snacks.nvim
**Local spec:** lua/plugins/snacks.lua:1-33
**Tags:** snacks meta plugin-suite folke

## Scope
Snacks bundles ~30 independent QoL modules behind a single `opts` table; each is opt-in via `<name>.enabled = true`. We load it eagerly (`lazy = false`, `priority = 1000`) so the dashboard renders before lazy starts loading deferred plugins, and so `vim.notify` / `vim.ui.input` / `vim.ui.select` are replaced from the very first redraw. Module-specific config and keymaps live in [snacks-picker](snacks-picker.md), [snacks-dashboard](snacks-dashboard.md), and [snacks-misc](snacks-misc.md).

## Install spec
```lua
{
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    image      = { enabled = true },
    picker     = { enabled = true, sources = { projects = { ... } } },
    lazygit    = { enabled = true },
    terminal   = { enabled = true },
    indent     = { enabled = true, animate = { enabled = false } },
    scroll     = { enabled = false },
    statuscolumn = { enabled = true },
    input      = { enabled = true },
    rename     = { enabled = true },
    bigfile    = { enabled = true, size = 500 * 1024 },
    words      = { enabled = false },
    notifier   = { enabled = true },
    quickfile  = { enabled = true },
    scope      = { enabled = true },
    scratch    = { enabled = true },
    dashboard  = { enabled = true, sections = { ... } },
  },
  keys = { ... },
}
```

## Common customizations
Every module is wired the same way — `opts.<module> = { enabled = bool, ... }`. Useful top-level keys (per `:help snacks.txt`):

- `<module>.enabled` *(bool, false)* — opt-in master switch. Snacks ships everything disabled.
- `styles` *(table)* — override the `snacks.win.Config` named styles (`float`, `terminal`, `notification`, `input`, `scratch`, …) globally.
- `dashboard`, `picker`, `notifier`, `terminal`, … each take their own option table (see per-module docs below).

## Our config — modules enabled and why
| Module | State | Reason |
|---|---|---|
| `image` | on | Inline image preview in markdown/LaTeX via Kitty graphics protocol (kitty terminal). |
| `picker` | on | Primary fuzzy-finder replacing telescope; see [snacks-picker](snacks-picker.md). |
| `lazygit` | on | `<leader>gg` floating lazygit; auto-themed from colorscheme. |
| `terminal` | on | Floating shell module — kept because `Snacks.lazygit` uses it internally. No direct keybind (tmux handles terminals). |
| `indent` | on, **animate off** | Static indent guides; animation disabled to avoid cursor jitter on fast motions. |
| `statuscolumn` | on | Replaces nvim's default — combines signs, marks, fold, git-signs. |
| `input` | on | Pretty `vim.ui.input` replacement (used by `:IncRename`, etc.). |
| `rename` | on | LSP-aware file rename (`<leader>fR`). |
| `bigfile` | on, `size = 500KB` | Threshold lowered from 1.5MB default — disables LSP/Treesitter on files over 500KB. |
| `notifier` | on | Replaces `vim.notify`. Conflicts with [ui-noice](ui-noice.md) if both route messages — we delegate notifications here. |
| `quickfile` | on | Renders the buffer before plugins finish loading on `nvim <file>`. |
| `scope` | on | Treesitter-aware scope detection for text objects + jumps. |
| `scratch` | on | Project-scoped persistent scratchpad (`<leader>.`). |
| `dashboard` | on | Startup screen; see [snacks-dashboard](snacks-dashboard.md). |

## Our config — modules disabled and why
| Module | Reason |
|---|---|
| `scroll` | Animated smooth-scroll disabled — distracting on long jumps, conflicts with relative-number redraws. |
| `words` | LSP reference highlights disabled — handled by treesitter + we don't want auto-jump on `]]`/`[[`. |

All other modules (animate, bufdelete, dim, explorer, gh, gitbrowse, keymap, profiler, toggle, zen, etc.) are simply omitted — they default to disabled.

## Keymaps
Top-level keymaps registered on the snacks spec — see per-module docs for the full table.

| Key | Mode | Action | Doc |
|---|---|---|---|
| `<leader>f*`, `<leader>s*`, `g[dryI]` | n | picker | [snacks-picker](snacks-picker.md) |
| `<leader>gg` | n | `Snacks.lazygit()` | [snacks-misc](snacks-misc.md) |
| `<leader>fR` | n | `Snacks.rename.rename_file()` | [snacks-misc](snacks-misc.md) |
| `<leader>.`, `<leader>fs` | n | `Snacks.scratch()` / `.select()` | [snacks-misc](snacks-misc.md) |

## Links
- README: https://github.com/folke/snacks.nvim
- Help: `:help snacks.txt`
- Related: [snacks-picker](snacks-picker.md), [snacks-dashboard](snacks-dashboard.md), [snacks-misc](snacks-misc.md), [editor-which-key](editor-which-key.md), [ui-noice](ui-noice.md)

## Notes
- `lazy = false` + `priority = 1000` is required for the dashboard and quickfile to fire before any other plugin's init runs.
- The `vim.g.gaf` flag (set by `GAF=1 nvim`, see auto-memory `nvim_gaf_profile.md`) gates GAF-specific additions inside picker/projects — see [snacks-picker](snacks-picker.md).
