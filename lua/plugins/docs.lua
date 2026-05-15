return {
  {
    "maskudo/devdocs.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = "DevDocs",
    keys = {
      { "<leader>ko", function() require("devdocs").get() end,     desc = "DevDocs open" },
      { "<leader>ki", function() require("devdocs").install() end, desc = "DevDocs install" },
      { "<leader>kf", "<cmd>DevDocs fetch<cr>",                    desc = "DevDocs fetch index" },
      { "<leader>kd", function() require("devdocs").delete() end,  desc = "DevDocs delete" },
    },
    opts = {
      ensure_installed = {
        "ruby~3.4", "rails~7.1",
        "javascript", "typescript", "node",
        "php", "html", "css", "http",
        "lua~5.1",
      },
    },
  },
}
