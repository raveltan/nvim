vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.showtabline = 0
opt.signcolumn = "yes"
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
opt.laststatus = 3
opt.smoothscroll = true
opt.fillchars = { eob = " ", fold = " ", foldopen = "", foldclose = "", foldsep = "│" }

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
opt.diffopt:append("vertical")
opt.diffopt:append("algorithm:histogram") -- cleaner diffs than the default myers
opt.diffopt:append("linematch:60")        -- align changed lines within a block (readable :Gdiffsplit / vimdiff / conflicts)
opt.virtualedit = "block"
opt.pumheight = 10
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
opt.colorcolumn = "80,150"
opt.formatoptions:remove("t")
vim.lsp.log.set_level(vim.log.levels.OFF)

-- No remote-plugin hosts in use; disabling skips provider probing and the
-- perl/ruby/node/python checkhealth warnings.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
