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
      -- Generate / destroy
      { "<leader>rg", function() require("ror.generators").select_generators() end,    desc = "Generate" },
      { "<leader>rd", function() require("ror.destroyers").select_destroyers() end,    desc = "Destroy" },
      -- Routes
      { "<leader>rr", function() require("ror.routes").list_routes() end,              desc = "List routes" },
      { "<leader>rR", function() require("ror.routes").sync_routes() end,              desc = "Sync routes" },
      -- Schema
      { "<leader>rs", function() require("ror.schema").list_table_columns() end,       desc = "Schema columns" },
      -- DB
      { "<leader>rm", function() require("ror.runners.db_migrate").run() end,          desc = "DB migrate" },
      { "<leader>rM", function() require("ror.runners.db_migrate_status").run() end,   desc = "DB migrate status" },
      { "<leader>rk", function() require("ror.runners.db_rollback").run() end,         desc = "DB rollback" },
      -- Bundle
      { "<leader>rb", function() require("ror.runners.bundle_install").run() end,      desc = "Bundle install" },
      { "<leader>rB", function() require("ror.runners.bundle_update").run() end,       desc = "Bundle update" },
      -- Console (terminal split)
      {
        "<leader>rC",
        function()
          local cmd = vim.fn.filereadable("bin/rails") == 1 and "bin/rails console" or "rails console"
          vim.cmd("botright split | resize 15 | terminal " .. cmd)
          vim.cmd("startinsert")
        end,
        desc = "Rails console",
      },
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

  -- Projectionist: :A alternate, :Emodel/:Econtroller/:Eview/:Espec/:Ehelper/:Ejob/...
  -- Heuristic below activates whenever both Gemfile and config/environment.rb exist
  -- (i.e. a Rails project). other.nvim still handles richer many-target picks via
  -- <leader>oo; projectionist owns the fast vim-rails-style :A and :E* commands.
  {
    "tpope/vim-projectionist",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      vim.g.projectionist_heuristics = {
        ["config/environment.rb&Gemfile"] = {
          ["app/controllers/*_controller.rb"] = {
            type = "controller",
            alternate = "spec/controllers/{}_controller_spec.rb",
            template = {
              "class {camelcase|capitalize|colons}Controller < ApplicationController",
              "end",
            },
          },
          ["spec/controllers/*_controller_spec.rb"] = {
            type = "spec",
            alternate = "app/controllers/{}_controller.rb",
          },
          ["app/models/*.rb"] = {
            type = "model",
            alternate = "spec/models/{}_spec.rb",
            template = {
              "class {camelcase|capitalize|colons} < ApplicationRecord",
              "end",
            },
          },
          ["spec/models/*_spec.rb"] = {
            type = "spec",
            alternate = "app/models/{}.rb",
          },
          ["app/views/*"] = { type = "view" },
          ["app/helpers/*_helper.rb"] = {
            type = "helper",
            alternate = "spec/helpers/{}_helper_spec.rb",
          },
          ["app/mailers/*.rb"] = {
            type = "mailer",
            alternate = "spec/mailers/{}_spec.rb",
          },
          ["app/jobs/*.rb"] = {
            type = "job",
            alternate = "spec/jobs/{}_spec.rb",
          },
          ["app/services/*.rb"] = {
            type = "service",
            alternate = "spec/services/{}_spec.rb",
          },
          ["app/policies/*_policy.rb"] = {
            type = "policy",
            alternate = "spec/policies/{}_policy_spec.rb",
          },
          ["app/serializers/*_serializer.rb"] = {
            type = "serializer",
            alternate = "spec/serializers/{}_serializer_spec.rb",
          },
          ["app/decorators/*_decorator.rb"] = {
            type = "decorator",
            alternate = "spec/decorators/{}_decorator_spec.rb",
          },
          ["app/forms/*_form.rb"] = {
            type = "form",
            alternate = "spec/forms/{}_form_spec.rb",
          },
          ["spec/factories/*.rb"]    = { type = "factory" },
          ["db/migrate/*.rb"]        = { type = "migration" },
          ["config/routes.rb"]       = { type = "routes" },
          ["config/database.yml"]    = { type = "database" },
          ["db/schema.rb"]           = { type = "schema" },
          ["Gemfile"]                = { type = "gemfile" },
          ["Rakefile"]               = { type = "rakefile" },
        },
      }
    end,
  },

  -- Auto-insert `end` for `def`/`do`/`if`/`class`/`module`. Treesitter doesn't.
  {
    "tpope/vim-endwise",
    ft = { "ruby", "eruby", "lua", "vim" },
  },

  -- Herb: HTML+ERB language server (parser, linter, formatter via LSP)
  -- Requires: npm install -g @herb-tools/language-server
  -- Docs: https://herb-tools.dev
  {
    "neovim/nvim-lspconfig",
    ft = { "eruby", "html" },
    config = function()
      if vim.fn.executable("herb-language-server") ~= 1 then
        return
      end
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("herb_ls", {
        capabilities = capabilities,
        cmd = { "herb-language-server", "--stdio" },
        filetypes = { "eruby", "html" },
        root_markers = { "Gemfile", ".git" },
      })
      vim.lsp.enable("herb_ls")
    end,
  },
}
