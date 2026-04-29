return {
  -- Rails navigation and tooling
  {
    "weizheheng/ror.nvim",
    ft = { "ruby", "eruby" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
      "nvim-telescope/telescope.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim",  build = "make" },
      { "nvim-telescope/telescope-ui-select.nvim" },
    },
    keys = {
      -- Command palette
      { "<leader>rc", function() require("ror.commands").list_commands() end,          desc = "Rails commands" },
      -- Finders
      { "<leader>rm", function() require("ror.finders.model").find() end,              desc = "Find models" },
      { "<leader>ro", function() require("ror.finders.controller").find() end,         desc = "Find controllers" },
      { "<leader>rv", function() require("ror.finders.view").find() end,               desc = "Find views" },
      { "<leader>rg", function() require("ror.finders.migration").find() end,          desc = "Find migrations" },
      { "<leader>rf", function() require("ror.finders.mailer").find() end,             desc = "Find mailers" },
      -- Routes
      { "<leader>rr", function() require("ror.routes").list_routes() end,              desc = "List routes" },
      { "<leader>rR", function() require("ror.routes").sync_routes() end,              desc = "Sync routes" },
      -- Schema
      { "<leader>rs", function() require("ror.schema").list_table_columns() end,       desc = "Schema columns" },
    },
    config = function()
      require("telescope").load_extension("fzf")
      require("telescope").load_extension("ui-select")
      require("ror").setup({})
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("ruby_lsp", {
        capabilities = capabilities,
        init_options = {
          formatter = "none", -- deferred to conform.nvim
          linters = { "rubocop" },
          addonSettings = {
            ["Ruby LSP Rails"] = {
              enablePendingMigrationsPrompt = true,
            },
          },
        },
      })
      vim.lsp.enable("ruby_lsp")
    end,
  },

  -- Ruby/ERB formatters
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.ruby = { "rubocop" }
      opts.formatters_by_ft.eruby = { "erb_format" }
    end,
  },
}
