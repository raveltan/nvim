local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  require("gaf.python_nav").setup()
  require("gaf.typing").setup()
  -- Angular selector navigation (`gd`, `<leader>c{p,G,R}`) plus the template
  -- completion source: GAF-only, so it starts here rather than in init.lua. Its
  -- blink provider is registered under the same flag in lua/plugins/lsp.lua.
  require("gaf.angular").setup()
  -- Phabricator inline review comments (lua/gaf/phab/): decorates buffers under
  -- a D<id> worktree with the revision's inline comments. Freelancer-only, so
  -- it starts here; the <leader>p maps and :Phab* commands only exist under GAF.
  require("gaf.phab").setup()
  -- Tag matching (`%`, `i%`/`a%`) lives in the in-repo lua/tagmatch/ module and is
  -- set up for everyone in init.lua, since it is not GAF-specific.
end

return M
