vim.g.gaf = vim.env.GAF == "1"

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
-- In-repo module (lua/tagmatch/), not a lazy.nvim plugin: setup only registers a
-- FileType autocmd + two <Plug> maps, so eager loading is negligible. Default
-- filetype list lives in the module.
require("tagmatch").setup()
require("gaf").setup()
