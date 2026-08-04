# config-options
> All global `vim.opt` settings, leader keys, and the two global non-option knobs (`vim.hl` priority, provider disabling).

**Local file:** lua/config/options.lua
**Tags:** config, options, ui, indent, search, fold, transparency

## Scope

`lua/config/options.lua` sets the editor-wide defaults: leader keys, UI/appearance, indent,
search, folding, splits, diff, and a handful of behavioural switches (`confirm`, `inccommand`,
`jumpoptions`). Filetype-specific overrides live in `after/ftplugin/*.lua`, not here.

Several options here only produce a visible effect in combination with something outside this
file — the terminal (see [terminal-ghostty-tmux](terminal-ghostty-tmux.md)) or the colorscheme
(see [ui-moonfly](ui-moonfly.md)). Those are called out below.

## Highlights

### Leaders

- `vim.g.mapleader = " "` — Space.
- `vim.g.maplocalleader = "\\"` — backslash for filetype-local maps.

There is **no** `clipboard = "unnamedplus"`: the system clipboard is synced through an explicit
`TextYankPost` handler instead (see [config-autocmds](config-autocmds.md)), because
`unnamedplus` spawns `pbcopy`/`pbpaste` uncached on every yank.

### UI & appearance

- `number`, `relativenumber` — hybrid line numbers. The *rendering* of the number column is
  owned by comfy-line-numbers.nvim via `'statuscolumn'`, not by these options alone.
- `termguicolors`, `cursorline`.
- `cursorlineopt = "number,line"` — highlights the line number as well; on a transparent
  background the row highlight alone is nearly invisible.
- `guicursor` — block in normal/visual/cmdline/select-mode, `ver25` bar in insert, `hor20` in
  replace/operator-pending, plus `blinkwait700-blinkoff400-blinkon250`. **Requires the tmux
  DECSCUSR override** to reach the terminal; without it this option does nothing inside tmux.
- `signcolumn = "yes:2"` — width 2, not 1. Four consumers compete for the gutter (gitsigns hunk
  bars, marks.nvim, diagnostic icons, nvim-lightbulb's bulb) and at width 1 the highest-priority
  sign silently hides the rest. See [lsp-lightbulb](lsp-lightbulb.md).
- `showtabline = 0` — no tabline at all. Pinned-file navigation is harpoon, surfaced in the
  statusline (see [nav-harpoon](nav-harpoon.md)); there is no bufferline plugin.
- `laststatus = 3` — single global statusline across all splits.
- `winborder = "rounded"` — every floating window, no per-plugin opt-in.
- `pumborder = "rounded"` — **0.12 option.** `'winborder'` covers floats only, so the *builtin*
  popup menu (`i_CTRL-X`, cmdline/wildmenu-as-pum) stayed square. blink.cmp draws its own menu;
  this covers everything blink does not own. `'pumblend'` deliberately left at 0 — a blended pum
  over a transparent `Normal` shows buffer text through the menu.
- `pumheight = 10`, `pummaxwidth = 80` — `'pumwidth'` is a *minimum*; without a maximum a long
  label stretches the builtin pum to the window edge.
- `list = true` + `listchars = { tab = "▸ ", trail = "·", nbsp = "␣", extends = "❯", precedes = "❮" }`
  — makes the characters you never want silently present visible; a literal tab is a bug in an
  `expandtab` config.
- `fillchars = { eob = " ", fold = " ", diff = "╱", foldopen = "", foldclose = "", foldsep = "│" }`
  — `diff:╱` replaces the default `-` filler rows in `:Gdiffsplit`/vimdiff so deleted-block
  filler reads as absence rather than content.
- `textwidth = 150`, `colorcolumn = "+1"` — one rule, tracking `'textwidth'` per buffer, so prose
  ftplugins (gitcommit at 72) get their own correct edge. `ColorColumn` is re-coloured in
  [ui-moonfly](ui-moonfly.md) because moonfly's default is invisible against a black terminal.
- `smoothscroll = true` — wrapped-line aware `<C-d>`/`<C-u>`.
- `wrap = true` — soft-wrap long lines.

### Indent

- `shiftwidth = 2`, `tabstop = 2`, `expandtab = true`.
- `autoindent`, `breakindent`.
- `smartindent` is intentionally **off**: *"smartindent is C-style; with indentexpr set it's
  ignored, and in Ruby it forces `#` comments to column 0. Rely on filetype indentexpr +
  autoindent instead."*

### Search

- `ignorecase` + `smartcase`.
- `inccommand = "split"` — live `:substitute` preview in a split.

### Fold

- `foldenable = true`, `foldlevel = 99`, `foldlevelstart = 99` — buffers open **fully unfolded**;
  `zM` closes all, `zr`/`zm` adjust level, `za`/`zc`/`zo` per fold.
- `foldcolumn = "0"` — comfy-line-numbers owns `'statuscolumn'` and its column string has no
  `%C`, so a fold column cannot render there. Fold state is visible via `foldtext` only.
- `foldtext = "v:lua.require'config.foldtext'.foldtext()"` — first line + line count.
  `vim.treesitter.foldtext()` does not exist in 0.12.
- Folds come from **treesitter `foldexpr`**, wired per-buffer in `lua/plugins/treesitter.lua`
  (only for buffers with a parser). nvim-ufo is **not** installed.

### Diff

- `diffopt:remove("linematch:40")` **first** — 0.12's default already carries `linematch:40`, so
  appending `linematch:60` left both values in the option string.
- then `:append("vertical")`, `:append("algorithm:histogram")`, `:append("linematch:60")`.
- Because these are appends rather than an assignment, 0.12's new `indent-heuristic` and
  `inline:char` defaults are inherited for free.

### Undo

- `undofile`, `undolevels = 10000`, `undoreload = 10000`.
- `undodir` pinned to `stdpath("state") .. "/undo"` and `mkdir`'d so history survives on a fresh
  machine. Note `undofile` is keyed to the file's content hash — checkout/branch-switch/external
  rewrites still drop history by design; reach orphaned branches with undotree + `g-`/`g+`.

### Highlight priority

`vim.hl.priorities.semantic_tokens = 95` — treesitter extmarks are 100 and LSP semantic tokens
default to 125, so `@lsp.type.*` overpainted every treesitter capture it overlapped
(neovim/neovim#33614, open). Demoting keeps tokens only where treesitter has nothing to say.
Must be set before the colorscheme loads. See [ui-moonfly](ui-moonfly.md).

### Misc behaviour

- `updatetime = 500` — faster `CursorHold` (gitsigns, lightbulb, hover hints).
- `scrolloff = 8`, `mouse = "a"`, `virtualedit = "block"`, `confirm = true`.
- `splitbelow`, `splitright`.
- `jumpoptions = "stack,view,clean"` — branching jump stack, view preserved on jump-back,
  `clean` drops entries whose buffer was wiped.
- `formatoptions:remove("t")` — `t` in the default `tcqj` auto-hard-wraps *code* at `textwidth`
  while typing; prose ftplugins re-add it per buffer.
- `shortmess:append("I")` — no intro screen.
- `vim.lsp.log.set_level(vim.log.levels.OFF)` — no LSP logfile growth.
- node/perl/python3/ruby providers disabled — no remote-plugin hosts in use; skips probing and
  the checkhealth warnings.

## Links

- Related [config-init](config-init.md), [config-keymaps](config-keymaps.md), [config-autocmds](config-autocmds.md)
- Appearance depends on: [ui-moonfly](ui-moonfly.md), [terminal-ghostty-tmux](terminal-ghostty-tmux.md)
- Gutter co-owners: [lsp-lightbulb](lsp-lightbulb.md), [git-gitsigns](git-gitsigns.md), [editor-marks](editor-marks.md)
- Folding detail: [editor-folding](editor-folding.md)
- Filetype-local overrides: `after/ftplugin/*.lua` (e.g. [ftplugin-php](ftplugin-php.md))

## Notes

- Three options here fail **silently** if the terminal side regresses: `guicursor` (needs the
  tmux DECSCUSR override), the transparency this file's `pumblend = 0` choice assumes (needs
  Ghostty `background-opacity`), and diagnostic underline styles (needs `Smulx`/`Setulc`).
- If you change `shiftwidth`/`tabstop`, also update `.editorconfig` so external tools agree.
- `'statuscolumn'` is **not** set here. comfy-line-numbers.nvim owns it globally and snacks'
  statuscolumn module is disabled for that reason — a second owner silently wins or loses at
  random. Its column string is `%=%s%=%{...}`, and the `%s` is what makes gitsigns/marks/
  lightbulb signs render at all.
