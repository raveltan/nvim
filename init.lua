vim.g.gaf = vim.env.GAF == "1"

vim.lsp.log.set_level(vim.log.levels.ERROR)

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("gaf").setup()
