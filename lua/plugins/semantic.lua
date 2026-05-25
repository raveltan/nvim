-- Semantic search over nvimdocs + devdocs.
-- Backed by ~/.ravelnvim.db built from scripts/semantic/index.py.
-- See README "Semantic search" section for first-time setup.

return {
  {
    dir = vim.fn.stdpath("config"),
    name = "semantic-search",
    dependencies = { "folke/snacks.nvim" },
    lazy = false,
    keys = {
      { "<leader>kx",  desc = "+semantic search" },
      { "<leader>kxx", function() require("semantic").pick("", "Semantic (all)") end,         desc = "Semantic: search all docs" },
      { "<leader>kxn", function() require("semantic").pick("nvimdocs", "Semantic (nvimdocs)") end, desc = "Semantic: search nvimdocs" },
      { "<leader>kxd", function() require("semantic").pick("devdocs", "Semantic (devdocs)") end,   desc = "Semantic: search devdocs" },
      { "<leader>kxr", function() require("semantic").rebuild(false, "nvimdocs,devdocs", "terminal") end,   desc = "Semantic: rebuild (term split, live)" },
      { "<leader>kxR", function() require("semantic").rebuild(true,  "nvimdocs,devdocs", "terminal") end,   desc = "Semantic: full rebuild (term split, live)" },
      { "<leader>kxb", function() require("semantic").rebuild(false, "nvimdocs,devdocs", "background") end, desc = "Semantic: rebuild (background, notify)" },
    },
    config = function()
      require("semantic").setup()
    end,
  },
}
