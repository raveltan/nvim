vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.showtabline = 0
-- yes:2, not yes: the gutter now hosts gitsigns hunk bars, marks.nvim marks,
-- diagnostic icons AND nvim-lightbulb's code-action bulb. At width 1 the
-- highest-priority sign silently hides the rest.
opt.signcolumn = "yes:2"
opt.shiftwidth = 2
opt.tabstop = 2
opt.expandtab = true
-- smartindent is C-style; with indentexpr set it's ignored, and in Ruby it forces
-- `#` comments to column 0. Rely on filetype indentexpr + autoindent instead.
opt.autoindent = true
opt.breakindent = true
opt.splitbelow = true
opt.splitright = true
opt.updatetime = 500
opt.cursorline = true
-- Highlight the line number too: on a transparent background the row highlight
-- alone is nearly invisible.
opt.cursorlineopt = "number,line"
-- Default guicursor has no blink. Bar caret in insert + a slow blink makes the
-- caret findable after a picker/float closes, without the strobe of a fast blink.
opt.guicursor = table.concat({
  "n-v-c-sm:block",
  "i-ci-ve:ver25",
  "r-cr-o:hor20",
  "a:blinkwait700-blinkoff400-blinkon250",
}, ",")
opt.scrolloff = 8
-- Persistent, deep undo. Pin undodir + ensure it exists so history survives
-- restarts even on a fresh machine. NOTE: undofile is keyed to the file's
-- content hash — git checkout / branch switch / external rewrites still drop
-- history by design; use undotree + g-/g+ to reach orphaned branches.
opt.undofile = true
opt.undolevels = 10000
opt.undoreload = 10000
local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"
opt.winborder = "rounded"
-- 0.12 added 'pumborder': 'winborder' only covers floats, so the BUILTIN popup
-- menu (i_CTRL-X completion, cmdline/wildmenu-as-pum) stayed square. blink.cmp
-- draws its own rounded menu, this matches everything blink does not own.
-- ('pumblend' left at 0 — moonfly's transparency means a blended pum would show
-- buffer text through the menu.)
opt.pumborder = "rounded"
opt.laststatus = 3
opt.smoothscroll = true
-- diff:╱ replaces the default '-' filler rows in :Gdiffsplit / vimdiff with a
-- diagonal hatch, so deleted-block filler reads as absence, not content.
opt.fillchars = { eob = " ", fold = " ", diff = "╱", foldopen = "", foldclose = "", foldsep = "│" }

-- Folding via treesitter foldexpr, wired per-buffer in lua/plugins/treesitter.lua
-- (set only for buffers with a parser; large/parserless buffers keep manual folds).
-- These globals keep everything open on load; zc/za fold a function on demand.
opt.foldenable = true       -- folds allowed; za/zc/zo work
opt.foldlevel = 99          -- all folds open on load; zM closes all, zr/zm adjust level
opt.foldlevelstart = 99     -- buffers open fully unfolded
-- comfy-line-numbers owns 'statuscolumn' (snacks statuscolumn is disabled), and
-- its column string has no %C, so a fold column can't render there -- keep it off.
-- (Fold state is still visible via foldtext + zM/zR; no gutter marks.)
opt.foldcolumn = "0"
-- Custom foldtext (first line + line count). vim.treesitter.foldtext() doesn't exist in 0.12.
opt.foldtext = "v:lua.require'config.foldtext'.foldtext()"
-- 0.12's default diffopt already carries indent-heuristic + inline:char (inherited
-- for free because these are appends, not an assignment) AND linematch:40 — so
-- appending linematch:60 left BOTH values in the option string. Drop the default
-- first so only one linematch is in effect.
opt.diffopt:remove("linematch:40")
opt.diffopt:append("vertical")
opt.diffopt:append("algorithm:histogram") -- cleaner diffs than the default myers
opt.diffopt:append("linematch:60")        -- align changed lines within a block (readable :Gdiffsplit / vimdiff / conflicts)
-- Show the characters you never want silently present: trailing whitespace,
-- nbsp, and a literal tab in an expandtab config.
opt.list = true
opt.listchars = { tab = "▸ ", trail = "·", nbsp = "␣", extends = "❯", precedes = "❮" }

opt.virtualedit = "block"
opt.pumheight = 10
-- 'pumwidth' is a minimum; without a maximum a long completion label stretches the
-- builtin pum to the window edge. (blink.cmp sizes its own menu; this is for
-- i_CTRL-X / cmdline completion.)
opt.pummaxwidth = 80

-- Treesitter extmarks are priority 100, LSP semantic tokens 125 — so @lsp.type.*
-- overpaints every treesitter capture it overlaps, which is why LSP-attached
-- buffers look flatter than the same file with the server stopped
-- (neovim/neovim#33614, open, no per-language knob). Demote tokens below
-- treesitter; they still win where treesitter has nothing to say.
vim.hl.priorities.semantic_tokens = 95
opt.confirm = true
opt.inccommand = "split"
-- "clean" (0.11+ default) drops jumplist entries whose buffer was wiped.
opt.jumpoptions = "stack,view,clean"
opt.shortmess:append("I")
opt.wrap = true
-- textwidth drives gq/gw formatting width only; drop "t" from the default
-- formatoptions ("tcqj") — "t" auto-hard-wraps code (not just comments)
-- while typing, inserting surprise newlines in long lines. Prose ftplugins
-- (markdown, gitcommit) re-add it per buffer where auto-wrap makes sense.
opt.textwidth = 150
-- One rule, not two: "80,150" drew a second vertical bar through every file in a
-- config whose actual wrap width is 150. "+1" tracks 'textwidth' per buffer, so
-- prose ftplugins (markdown, gitcommit at 72) get their own correct edge.
opt.colorcolumn = "+1"
opt.formatoptions:remove("t")
vim.lsp.log.set_level(vim.log.levels.OFF)

-- No remote-plugin hosts in use; disabling skips provider probing and the
-- perl/ruby/node/python checkhealth warnings.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
