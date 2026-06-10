vim.g.gaf = vim.env.GAF == "1"

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("gaf").setup()
