vim.g.gaf = vim.env.GAF == "1"

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
-- In-repo modules (lua/tagmatch/, lua/angular/), not lazy.nvim plugins: setup
-- only registers FileType autocmds + a couple of maps, so eager loading is
-- negligible. Neither is GAF-specific -- tag matching works in any markup, and
-- Angular navigation in any Angular project -- so both load for everyone.
require("tagmatch").setup()
require("angular").setup()
require("gaf").setup()
