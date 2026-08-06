vim.g.gaf = vim.env.GAF == "1"

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
-- In-repo module (lua/tagmatch/), not a lazy.nvim plugin: setup only registers
-- FileType autocmds + a couple of maps, so eager loading is negligible. Tag
-- matching works in any markup, so it loads for everyone. The Angular module
-- (lua/gaf/angular/) is GAF-only and starts from require("gaf") below.
require("tagmatch").setup()
require("gaf").setup()
-- Laravel is detected per buffer from an `artisan` file, not from an env flag,
-- so this is loaded for everyone and no-ops outside a Laravel checkout (and
-- returns immediately under GAF=1). See lua/artisan/init.lua.
require("artisan").setup()
