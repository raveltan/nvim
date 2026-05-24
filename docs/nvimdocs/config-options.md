# config-options
> All global `vim.opt` settings and leader keys.

**Local file:** lua/config/options.lua
**Tags:** config, options, ui, indent, search, fold

## Scope

`lua/config/options.lua` sets the editor-wide defaults: leader keys, clipboard, UI tweaks, indent, search, fold, splits, and a handful of behavioural switches (`confirm`, `inccommand`, `jumpoptions`). Filetype-specific overrides live in `after/ftplugin/*.lua`, not here.

## Highlights

### Leaders
- `vim.g.mapleader = " "` — Space.
- `vim.g.maplocalleader = "\\"` — backslash for filetype-local maps.

### Clipboard & UI
- `clipboard = "unnamedplus"` — system clipboard shared with yank/put.
- `number`, `relativenumber` — hybrid line numbers.
- `termguicolors`, `cursorline`, `signcolumn = "yes"`, `winborder = "rounded"`.
- `showtabline = 0` — bufferline plugin owns the top bar; the native tabline stays hidden.
- `laststatus = 3` — single global statusline across all splits.
- `pumheight = 10` — cap completion menu height.
- `fillchars = { eob = " " }` — blank out the `~` end-of-buffer marker.

### Indent
- `shiftwidth = 2`, `tabstop = 2`, `expandtab = true`.
- `autoindent = true`, `breakindent = true`.
- `smartindent` is intentionally **off**. Cited verbatim from the source: *"smartindent is C-style; with indentexpr set it's ignored, and in Ruby it forces `#` comments to column 0. Rely on filetype indentexpr + autoindent instead."*

### Search
- `ignorecase` + `smartcase` — case-insensitive unless the pattern has uppercase.
- `inccommand = "split"` — live preview of `:substitute` in a split.

### Fold
- `foldcolumn = "1"`, `foldenable = true`.
- `foldlevel = 99`, `foldlevelstart = 99` — open everything by default; UFO / treesitter folds become available without auto-collapsing.

### Splits & windows
- `splitbelow`, `splitright` — natural placement.
- `diffopt:append("vertical")` — `:diffsplit` opens side-by-side.

### Misc behaviour
- `updatetime = 500` — faster `CursorHold` (gitsigns, hover hints).
- `scrolloff = 8` — keep 8 lines of context.
- `undofile = true` — persistent undo across restarts.
- `mouse = "a"` — mouse on in all modes.
- `virtualedit = "block"` — visual-block can move past EOL.
- `confirm = true` — prompt instead of erroring on unsaved quit.
- `jumpoptions = "stack,view"` — branching jump stack + preserves view on jump-back.
- `shortmess:append("I")` — suppress the intro screen.
- `smoothscroll = true` — wrapped-line aware `<C-d>`/`<C-u>`.
- `wrap = true` — soft-wrap long lines.

## Full listing

```lua
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

opt.clipboard = "unnamedplus"
opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.showtabline = 0
opt.signcolumn = "yes"
opt.shiftwidth = 2
opt.tabstop = 2
opt.expandtab = true
opt.autoindent = true
opt.breakindent = true
opt.splitbelow = true
opt.splitright = true
opt.updatetime = 500
opt.cursorline = true
opt.scrolloff = 8
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"
opt.winborder = "rounded"
opt.laststatus = 3
opt.smoothscroll = true
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.fillchars = { eob = " " }
opt.diffopt:append("vertical")
opt.virtualedit = "block"
opt.pumheight = 10
opt.confirm = true
opt.inccommand = "split"
opt.jumpoptions = "stack,view"
opt.shortmess:append("I")
opt.wrap = true
```

## Links

- Related [config-init](config-init.md)
- Related [config-keymaps](config-keymaps.md)
- Filetype-local overrides: `after/ftplugin/*.lua` (e.g. [ftplugin-php](ftplugin-php.md)).

## Notes

- Folds default to open (`foldlevel = 99`); use `zc` to collapse the current one.
- `winborder = "rounded"` is a Neovim 0.11+ option — applies to every floating window without each plugin needing to opt in.
- If you change `shiftwidth`/`tabstop`, also update `.editorconfig` so external tools agree.
