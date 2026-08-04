# snacks-core
> Overview of folke/snacks.nvim — the QoL meta-plugin, which modules we enable, and why.

**Repo:** https://github.com/folke/snacks.nvim
**Local spec:** lua/plugins/snacks.lua:3
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
  init = function() ... end,        -- Snacks.toggle registry, see below
  opts = {
    styles     = { notification = { wo = { winblend = 0 } } },
    image      = { enabled = true },
    picker     = { enabled = true, layout = { preset = "telescope", cycle = true }, sources = { ... } },
    lazygit    = { enabled = true },
    terminal   = { enabled = true },
    indent     = { enabled = true, animate = { enabled = false } },
    scroll     = { enabled = false },
    statuscolumn = { enabled = false },
    input      = { enabled = true },
    rename     = { enabled = true },
    bigfile    = { enabled = true, size = 500 * 1024 },
    words      = { enabled = false },
    notifier   = { enabled = true, style = "fancy", top_down = true },
    quickfile  = { enabled = true },
    scope      = { enabled = true },
    scratch    = { enabled = false },
    zen        = { enabled = true },
    dim        = { enabled = true },
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
| `image` | on | Inline image preview via the Kitty graphics protocol. Needs Ghostty/kitty + tmux `allow-passthrough on` + `magick`; `pdflatex` is missing so LaTeX/math silently doesn't render — see [terminal-ghostty-tmux](terminal-ghostty-tmux.md). |
| `picker` | on | Primary fuzzy-finder replacing telescope, with per-source layouts; see [snacks-picker](snacks-picker.md). |
| `lazygit` | on | `<leader>gg` floating lazygit; auto-themed from colorscheme. |
| `terminal` | on | `<leader>/` bottom-docked toggle, adopted by edgy so it gets a title bar and obeys `exit_when_last` — see [ui-edgy](ui-edgy.md). |
| `indent` | on, **animate off** | Static indent guides; animation disabled to avoid cursor jitter on fast motions. |
| `input` | on | Pretty `vim.ui.input` replacement. |
| `rename` | on | LSP-aware file rename (`<leader>fR`). |
| `bigfile` | on, `size = 500KB` | Threshold lowered from 1.5MB default — disables LSP/Treesitter on files over 500KB. |
| `notifier` | on, `style = "fancy"` | Replaces `vim.notify`. Bordered box with icon + title row; `top_down = true` keeps it clear of fidget's bottom-right LSP progress window. History on `<leader>uN`. |
| `quickfile` | on | Renders the buffer before plugins finish loading on `nvim <file>`. |
| `scope` | on | Treesitter-aware scope detection for text objects + jumps. Also the reason mini.indentscope is **not** installed — same algorithm. |
| `zen` | on | `<leader>uz` distraction-free, `<leader>uZ` zoom (works with edgy panels open, unlike `<C-w>o`). |
| `dim` | on | `<leader>uD` dims inactive scopes. |
| `dashboard` | on | Startup screen; see [snacks-dashboard](snacks-dashboard.md). |

## Our config — modules disabled and why
| Module | Reason |
|---|---|
| `scroll` | Animated smooth-scroll disabled — distracting on long jumps, conflicts with relative-number redraws. |
| `words` | LSP reference highlights disabled — we don't want auto-jump on `]]`/`[[`. |
| `statuscolumn` | comfy-line-numbers.nvim owns `'statuscolumn'` globally and overwrites it on `BufReadPre` anyway. One owner, no fight over the number column. |
| `scratch` | Unused in practice. |
| `explorer` | canola.nvim (oil fork) owns `<leader>e`/`-` with `default_file_explorer = true`; enabling this would fight it for netrw takeover. snacks.explorer is also not buffer-editable, which is the whole reason oil is kept — see [nav-oil](nav-oil.md). |

Remaining modules (animate, bufdelete, debug, gh, git, gitbrowse, keymap, layout, profiler, toggle, win) are **libraries**, not opt-in features: they are always loaded and do nothing until called. `toggle` is called (below); the rest are unused API surface.

## Our config — the toggle registry

`init` registers a `VeryLazy` autocmd that builds the `Snacks.toggle` registry. Raw
`Snacks.zen()`-style calls were replaced by registry entries because only the registry gives
which-key the on/off colour, the icon swap, the Enable/Disable description flip and the notify.

```lua
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("conceallevel", { off = 0, on = 2, name = "Conceal" }):map("<leader>uc")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.treesitter():map("<leader>uT")
Snacks.toggle.indent():map("<leader>ug")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.diagnostics():map("<leader>ux")
Snacks.toggle.dim():map("<leader>uD")
Snacks.toggle.zen():map("<leader>uz")
Snacks.toggle.zoom():map("<leader>uZ")
Snacks.toggle.profiler():map("<leader>up")
```

Key-choice constraints: `<leader>ud*` is the duck group and `<leader>ur` is the resize submode
(`lua/config/keymaps.lua`), so diagnostics takes `<leader>ux` rather than the upstream `ud`.
Deferred to `VeryLazy` because the registry only exists after `setup()`.

## Keymaps
Top-level keymaps registered on the snacks spec — see per-module docs for the full table.

| Key | Mode | Action | Doc |
|---|---|---|---|
| `<leader>f*`, `<leader>s*`, `g[dryI]` | n | picker | [snacks-picker](snacks-picker.md) |
| `<leader>gg` | n | `Snacks.lazygit()` | [snacks-misc](snacks-misc.md) |
| `<leader>fR` | n | `Snacks.rename.rename_file()` | [snacks-misc](snacks-misc.md) |
| `<leader>/` | n | `Snacks.terminal.toggle()` (bottom dock) | [snacks-misc](snacks-misc.md) |
| `<leader>uN` | n | `Snacks.notifier.show_history()` | [snacks-misc](snacks-misc.md) |
| `<leader>u{s,w,c,L,l,T,g,h,x,D,z,Z,p}` | n | toggle registry | this doc |

## Links
- README: https://github.com/folke/snacks.nvim
- Help: `:help snacks.txt`
- Related: [snacks-picker](snacks-picker.md), [snacks-dashboard](snacks-dashboard.md), [snacks-misc](snacks-misc.md), [editor-which-key](editor-which-key.md), [ui-noice](ui-noice.md)

## Notes
- `lazy = false` + `priority = 1000` is required for the dashboard and quickfile to fire before any other plugin's init runs.
- `styles` is the single lever that re-skins **every** snacks surface at once (picker, notifier,
  input, zen, lazygit, blame). Only `notification.wo.winblend = 0` is overridden: `style = "fancy"`
  ships `winblend = 5`, and any blend over a transparent `Normal` muddies the notification against
  the buffer text behind it. Borders are not set here — `'winborder'` already propagates globally.
- Snacks floats inherit `NormalFloat`, which is deliberately kept **solid** — see
  [ui-moonfly](ui-moonfly.md).
- The `vim.g.gaf` flag (set by `GAF=1 nvim`, see auto-memory `nvim_gaf_profile.md`) gates GAF-specific additions inside picker/projects — see [snacks-picker](snacks-picker.md).
