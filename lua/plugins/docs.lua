return {
  {
    "maskudo/devdocs.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = "DevDocs",
    keys = {
      { "<leader>ko", "<cmd>DevDocs get<cr>",     desc = "DevDocs open" },
      { "<leader>ki", "<cmd>DevDocs install<cr>", desc = "DevDocs install" },
      { "<leader>kf", "<cmd>DevDocs fetch<cr>",   desc = "DevDocs fetch index" },
      { "<leader>kd", "<cmd>DevDocs delete<cr>",  desc = "DevDocs delete" },
    },
    opts = {
      ensure_installed = {
        "ruby~4", "rails~8.1",
        "javascript", "typescript", "node",
        "php", "html", "css", "http", "lua~5.1",
        "tailwindcss", "react", "angular",
        "markdown", "nginx", "sqlite",
        "bash", "git", "docker", "redis",
        "sass", "rspec", "minitest", "playwright",
      },
    },
  },
}
