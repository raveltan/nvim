local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  require("gaf.keymaps").setup()
end

return M
