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
-- smartindent is C-style; with indentexpr set it's ignored, and in Ruby it forces
-- `#` comments to column 0. Rely on filetype indentexpr + autoindent instead.
opt.autoindent = true
opt.breakindent = true
opt.splitbelow = true
opt.splitright = true
opt.updatetime = 200
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
opt.jumpoptions = "view"
opt.shortmess:append("I")
opt.wrap = true
