local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  -- Tag matching (`%`, `i%`/`a%`) moved to the general tagmatch.nvim plugin -- it
  -- handles Angular inline templates plus html/jsx/eruby/php/... for everyone.
end

return M
