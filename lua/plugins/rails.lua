return {
  -- tpope/vim-rails: :A/:E* navigation, :Rextract, :Rinvert, context-aware `gf`
  -- on partials/fixtures/factories, Rails syntax tweaks. Also the load carrier
  -- for the Ruby LSP stack (ruby_lsp, sorbet, stimulus) on ruby/eruby buffers.
  {
    "tpope/vim-rails",
    ft = { "ruby", "eruby" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    -- Custom projections for gem conventions vim-rails doesn't ship natively
    -- (Pundit/AMS/Draper/form objects). Each adds :E<command> + wires :A→spec,
    -- :R→model. Native :Emodel/:Eview/:Econtroller/:Ehelper/:Emailer/:Ejob/:Espec
    -- already cover the rest — these replace the old other.nvim Rails mappings,
    -- giving vim-rails sole ownership of Rails navigation (context-aware :R).
    -- Set in `init` so g:rails_projections exists before the plugin loads.
    init = function()
      vim.g.rails_projections = {
        ["app/policies/*_policy.rb"] = {
          command = "policy",
          affinity = "model",
          alternate = "spec/policies/{}_policy_spec.rb",
          related = "app/models/{}.rb",
        },
        ["app/serializers/*_serializer.rb"] = {
          command = "serializer",
          affinity = "model",
          alternate = "spec/serializers/{}_serializer_spec.rb",
          related = "app/models/{}.rb",
        },
        ["app/decorators/*_decorator.rb"] = {
          command = "decorator",
          affinity = "model",
          alternate = "spec/decorators/{}_decorator_spec.rb",
          related = "app/models/{}.rb",
        },
        ["app/forms/*_form.rb"] = {
          command = "form",
          affinity = "model",
          alternate = "spec/forms/{}_form_spec.rb",
          related = "app/models/{}.rb",
        },
        -- Avo admin (v3 layout: app/avo/resources/<model>.rb = Avo::Resources::<Model>).
        -- On Avo 2 the resource file is *_resource.rb — swap the glob below if so.
        ["app/avo/resources/*.rb"] = {
          command = "resource",
          affinity = "model",
          related = "app/models/{}.rb",
        },
        ["app/avo/actions/*.rb"] = { command = "avoaction" },
        ["app/avo/filters/*.rb"] = { command = "avofilter" },
        ["app/avo/dashboards/*.rb"] = { command = "dashboard" },
        ["app/avo/cards/*.rb"] = { command = "card" },
        ["app/avo/resource_tools/*.rb"] = {
          command = "resourcetool",
          related = "app/views/avo/resource_tools/_{}.html.erb",
        },
        -- FactoryBot: files are pluralised (spec/factories/users.rb), so the
        -- model<->factory name bridge is unreliable — command-only, no :A wiring.
        ["spec/factories/*.rb"] = { command = "factory" },
        -- ActiveJob: :Ejob is auto-defined (app/jobs/*_job.rb); add :A -> spec.
        ["app/jobs/*_job.rb"] = {
          command = "job",
          alternate = "spec/jobs/{}_job_spec.rb",
        },
        -- ActionMailer previews (Rails defaults previews to test/mailers/previews/
        -- even under RSpec; some projects use spec/mailers/previews/). :R -> mailer.
        ["test/mailers/previews/*_mailer_preview.rb"] = {
          command = "mailerpreview",
          related = "app/mailers/{}_mailer.rb",
        },
        ["spec/mailers/previews/*_mailer_preview.rb"] = {
          command = "mailerpreview",
          related = "app/mailers/{}_mailer.rb",
        },
        -- Hotwire/Turbo: :Eturbostream users/create -> app/views/users/create.turbo_stream.erb
        -- (* spans dirs in projectionist, so the controller/action path is the arg).
        ["app/views/*.turbo_stream.erb"] = { command = "turbostream" },
        -- Stimulus controllers (pairs with stimulus_ls configured below). Adjust the
        -- path if you use app/frontend/controllers or a jsbundling/importmap layout.
        ["app/javascript/controllers/*_controller.js"] = { command = "stimulus" },
      }
    end,
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      -- Override nvim-lspconfig's ruby_lsp reuse_client. The shipped version
      -- (lsp/ruby_lsp.lua) compares `client.config.cmd_cwd == config.cmd_cwd`
      -- but only side-effect-sets cmd_cwd on the NEW config — the existing
      -- client's stored cmd_cwd stays nil, so the second buffer attach
      -- always fails the reuse check and spawns a second client. We replace
      -- it with the standard name + root_dir comparison.
      vim.lsp.config("ruby_lsp", {
        capabilities = capabilities,
        cmd_env = { BUNDLE_QUIET = "1" },
        flags = { debounce_text_changes = 500 },
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
            excludedPatterns = {
              "**/db/schema.rb",
              "**/db/*_schema.rb",
              "**/coverage/**",
              "**/node_modules/**",
              "**/tmp/**",
              "**/vendor/**",
              "**/log/**",
            },
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

      -- Codelens intentionally NOT enabled (user preference: always disabled).
      -- vim.lsp.codelens.enable() is never called, so ruby_lsp lenses (route →
      -- controller / view links via rubyLsp.openFile) stay off.
    end,
  },

  -- DAP adapter for rdbg lives in plugins/dap.lua as a dependency of nvim-dap, so
  -- it loads on demand when you start debugging (not on every ruby buffer).

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

  -- Auto-insert `end` for `def`/`do`/`if`/`class`/`module`.
  -- Restored after nvim-treesitter-endwise broke (upstream regression w/ TS main branch).
  {
    "tpope/vim-endwise",
    ft = { "ruby", "eruby", "lua", "vim", "sh", "bash", "zsh" },
  },

  -- Herb (HTML+ERB language server) moved to lua/plugins/lsp.lua: a second
  -- nvim-lspconfig spec with its own `config` would clobber the main LSP config
  -- (lazy.nvim last-wins merge for non-list props).
}
