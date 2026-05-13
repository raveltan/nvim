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
      -- Command palette — covers infrequent commands (destroy, migrate status,
      -- bundle update, sync routes, coverage) so they don't need top-level keys.
      { "<leader>rc", function() require("ror.commands").list_commands() end,          desc = "Rails commands" },
      -- Generate
      { "<leader>rg", function() require("ror.generators").select_generators() end,    desc = "Generate" },
      -- Routes
      { "<leader>rr", function() require("ror.routes").list_routes() end,              desc = "List routes" },
      -- Schema
      { "<leader>rs", function() require("ror.schema").list_table_columns() end,       desc = "Schema columns" },
      -- DB
      { "<leader>rm", function() require("ror.runners.db_migrate").run() end,          desc = "DB migrate" },
      { "<leader>rk", function() require("ror.runners.db_rollback").run() end,         desc = "DB rollback" },
      -- Bundle
      { "<leader>rb", function() require("ror.runners.bundle_install").run() end,      desc = "Bundle install" },
      -- Console / credentials (terminal splits)
      {
        "<leader>rC",
        function()
          local cmd = vim.fn.filereadable("bin/rails") == 1 and "bin/rails console" or "rails console"
          vim.cmd("botright split | resize 15 | terminal " .. cmd)
          vim.cmd("startinsert")
        end,
        desc = "Rails console",
      },
      {
        "<leader>re",
        function()
          local cmd = vim.fn.filereadable("bin/rails") == 1 and "bin/rails credentials:edit" or "rails credentials:edit"
          vim.cmd("botright split | resize 15 | terminal " .. cmd)
          vim.cmd("startinsert")
        end,
        desc = "Edit credentials",
      },
    },
    config = function()
      require("telescope").load_extension("fzf")
      require("telescope").load_extension("ui-select")
      require("ror").setup({})
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      -- Override nvim-lspconfig's ruby_lsp reuse_client. The shipped version
      -- (lsp/ruby_lsp.lua) compares `client.config.cmd_cwd == config.cmd_cwd`
      -- but only side-effect-sets cmd_cwd on the NEW config — the existing
      -- client's stored cmd_cwd stays nil, so the second buffer attach
      -- always fails the reuse check and spawns a second client. We replace
      -- it with the standard name + root_dir comparison.
      vim.lsp.config("ruby_lsp", {
        capabilities = capabilities,
        reuse_client = function(client, config)
          return client.name == config.name and client.root_dir == config.root_dir
        end,
        init_options = {
          formatter = "none", -- deferred to conform.nvim
          linters = { "rubocop" },
          -- ruby-lsp-rails PR #660 (Dec 2025) added documentSymbol for
          -- db/schema.rb. The generic indexer ALSO walks schema.rb, so
          -- ActiveRecord::Schema ends up indexed twice -> duplicate
          -- "Schema" completion items with identical hover. Excluding
          -- schema.rb from the generic index drops the dup.
          indexing = {
            excludedPatterns = { "**/db/schema.rb", "**/db/*_schema.rb" },
          },
          addonSettings = {
            ["Ruby LSP Rails"] = {
              enablePendingMigrationsPrompt = true,
            },
          },
        },
      })
      vim.lsp.enable("ruby_lsp")

      -- Sorbet. Prefer direct `srb` binary; fall back to bundle exec.
      vim.lsp.config("sorbet", {
        capabilities = capabilities,
        cmd = vim.fn.executable("srb") == 1
          and { "srb", "tc", "--lsp", "--disable-watchman" }
          or { "bundle", "exec", "srb", "tc", "--lsp", "--disable-watchman" },
        filetypes = { "ruby" },
        -- root_markers with "sorbet/config" doesn't work — vim.fs.find
        -- matches basenames only, returning the sorbet/ dir as root.
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local sorbet_dir = vim.fs.find("sorbet", {
            upward = true,
            type = "directory",
            path = vim.fs.dirname(fname),
          })[1]
          if sorbet_dir then on_dir(vim.fs.dirname(sorbet_dir)) end
        end,
      })
      vim.lsp.enable("sorbet")

      -- Stimulus LSP (Hotwired). Completion + go-to-definition for
      -- data-controller / data-action / data-*-target. Requires:
      --   npm i -g stimulus-language-server
      if vim.fn.executable("stimulus-language-server") == 1 then
        vim.lsp.config("stimulus_ls", {
          capabilities = capabilities,
          cmd = { "stimulus-language-server", "--stdio" },
          filetypes = { "eruby", "html", "ruby" },
          root_markers = { "Gemfile", ".git" },
        })
        vim.lsp.enable("stimulus_ls")
      end

      -- ruby_lsp CodeLens: handle rubyLsp.openFile execute_command requests
      -- so route → controller action and action → view links work.
      -- URI may carry `#L<line>` fragment; strip it and jump to that line.
      vim.lsp.commands["rubyLsp.openFile"] = function(cmd)
        local arg = cmd.arguments and cmd.arguments[1]
        if not arg then return end
        if type(arg) == "table" then arg = arg[1] end
        local uri, line = arg:match("^(.+)#L(%d+)$")
        if not uri then uri = arg end
        local bufnr = vim.uri_to_bufnr(uri)
        vim.fn.bufload(bufnr)
        vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_win_set_cursor(0, { tonumber(line) or 1, 0 })
      end

      -- Auto-refresh codelens on Ruby buffers (LSP codelens not refreshed by default).
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        pattern = { "*.rb", "*.erb" },
        callback = function(args)
          if next(vim.lsp.get_clients({ bufnr = args.buf })) then
            vim.lsp.codelens.refresh({ bufnr = args.buf })
          end
        end,
      })

      -- Run codelens under cursor (Ruby buffers).
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "ruby", "eruby" },
        callback = function(args)
          vim.keymap.set("n", "<leader>cc", vim.lsp.codelens.run,
            { buffer = args.buf, desc = "Run codelens" })
        end,
      })
    end,
  },

  -- tpope/vim-rails: :Rextract, :Rinvert, context-aware `gf` on partials/
  -- fixtures/factories, Rails syntax tweaks. Coexists with projectionist.
  {
    "tpope/vim-rails",
    ft = { "ruby", "eruby" },
  },

  -- DAP adapter for rdbg / Ruby debug gem (Ruby 3.1+ ships it).
  -- Launch Rails with: RUBY_DEBUG_OPEN=true bin/rails s, then <leader>dc attach.
  {
    "suketa/nvim-dap-ruby",
    ft = "ruby",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function() require("dap-ruby").setup() end,
  },

  -- SimpleCov gutter signs + summary buffer. Reads coverage/.resultset.json.
  {
    "andythigpen/nvim-coverage",
    ft = { "ruby", "eruby" },
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "Coverage", "CoverageLoad", "CoverageShow", "CoverageHide", "CoverageToggle", "CoverageSummary" },
    opts = { auto_reload = true },
  },


  -- Ruby/ERB formatters
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.ruby = { "rubocop" }
      opts.formatters_by_ft.eruby = { "erb_format" }
      -- Use rubocop daemon (--server) and route diagnostics to stderr so
      -- bundler's "Resolving dependencies..." can't leak into stdout (which
      -- conform reads as formatted source and would prepend to the buffer).
      opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
        rubocop = {
          command = "rubocop",
          args = { "--server", "--stderr", "--stdin", "$FILENAME", "-a", "--fail-level", "fatal" },
        },
      })
    end,
  },

  -- Projectionist: :A alternate, :Emodel/:Econtroller/:Eview/:Espec/:Ehelper/:Ejob/...
  -- Heuristic below activates whenever both Gemfile and config/environment.rb exist
  -- (i.e. a Rails project). other.nvim still handles richer many-target picks via
  -- <leader>oo; projectionist owns the fast vim-rails-style :A and :E* commands.
  {
    "tpope/vim-projectionist",
    ft = { "ruby", "eruby" },
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

  -- Auto-insert `end` for `def`/`do`/`if`/`class`/`module`.
  -- Restored after nvim-treesitter-endwise broke (upstream regression w/ TS main branch).
  {
    "tpope/vim-endwise",
    ft = { "ruby", "eruby", "lua", "vim", "sh", "bash", "zsh" },
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
