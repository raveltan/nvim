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

-- Folding. foldmethod/foldexpr are NOT set here — they're applied per-buffer in
-- the treesitter FileType autocmd (lua/plugins/treesitter.lua) so only buffers
-- with a parser (and under the large-buffer guard) get native treesitter folds.
-- vim.treesitter.foldtext() does not exist in 0.12, so foldtext is a custom fn.
opt.foldenable = true       -- folds allowed; za/zc/zo work
opt.foldlevel = 99          -- open everything by default (no collapse-on-open)
opt.foldlevelstart = 99     -- new windows start fully unfolded
opt.foldnestmax = 4         -- don't fold absurdly deep
opt.foldcolumn = "1"        -- REQUIRED: snacks statuscolumn only draws fold marks when foldcolumn ~= "0"
opt.foldtext = "v:lua.require'config.foldtext'.foldtext()"
opt.diffopt:append("vertical")
opt.virtualedit = "block"
opt.pumheight = 10
opt.confirm = true
opt.inccommand = "split"
opt.jumpoptions = "stack,view"
opt.shortmess:append("I")
opt.wrap = true
opt.textwidth = 150
opt.colorcolumn = "80,150"
opt.formatoptions:append("t")

-- LSP logging OFF. The stale-cancel spam ("Cannot find request with id N whilst
-- attempting to cancel") is emitted at ERROR level (vim/lsp/client.lua), so it
-- passes every threshold except OFF — WARN/ERROR thresholds still write it
-- (87k+ lines, ~95% of a 32MB log, ruby_lsp worst). Each write is a blocking
-- io.write+flush on the main loop; bursts of 30+/sec while typing stalled the UI
-- and made blink.cmp + which-key fail to render. OFF disables lsp.log entirely;
-- re-enable temporarily for debugging with :lua vim.lsp.log.set_level("error").
vim.lsp.log.set_level(vim.log.levels.OFF)
