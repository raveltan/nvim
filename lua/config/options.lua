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

-- Folding. nvim-ufo (lua/plugins/fold.lua) drives folds: it sets
-- foldmethod=manual and applies LSP/treesitter folds itself, and renders
-- foldtext via its own fold_virt_text_handler. These global opts are the
-- baseline ufo requires (foldenable + high foldlevel = open on load).
opt.foldenable = true       -- folds allowed; za/zc/zo and z1..z5 work
opt.foldlevel = 99         -- all folds open on load; zM/z1..z5 re-fold on demand
opt.foldlevelstart = 99     -- buffers open fully unfolded (zM closes all, z1..z5 re-fold)
opt.foldcolumn = "1"        -- REQUIRED: snacks statuscolumn only draws fold marks when foldcolumn ~= "0"
-- foldtext fallback for buffers ufo doesn't manage (ufo overrides it per-buffer).
-- vim.treesitter.foldtext() does not exist in 0.12, so this is a custom fn.
opt.foldtext = "v:lua.require'config.foldtext'.foldtext()"
opt.diffopt:append("vertical")
opt.diffopt:append("algorithm:histogram") -- cleaner diffs than the default myers
opt.diffopt:append("linematch:60")        -- align changed lines within a block (readable :Gdiffsplit / vimdiff / conflicts)
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
