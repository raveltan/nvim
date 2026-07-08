local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  -- Tag matching (`%`, `i%`/`a%`) lives in the in-repo lua/tagmatch/ module, and
  -- Angular selector navigation (`gd`, `<leader>c{p,G,R}`) in lua/angular/ -- both
  -- set up for everyone in init.lua, since neither is GAF-specific.
end

return M
