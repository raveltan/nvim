return {
  -- Format-on-save for every filetype (saved buffer only), plus manual <leader>cf.
  -- Escape hatch: vim.g.disable_autoformat / vim.b.disable_autoformat.
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format file" },
    },
    opts = function(_, opts)
      local formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        -- vue_ls's own formatter is switched off in lsp.lua, so prettier (which
        -- parses SFCs natively) is the single owner.
        vue = { "prettierd", "prettier", stop_after_first = true },
        -- stylelint first: the GAF webapp formats scss via `stylelint --fix`
        -- (its prettier only covers *.ts). conform resolves stylelint from
        -- node_modules and skips it when a project doesn't ship it, falling
        -- through to prettier for other repos.
        scss = { "stylelint", "prettierd", "prettier", stop_after_first = true },
        css = { "stylelint", "prettierd", "prettier", stop_after_first = true },
        -- html LSP has provideFormatter = false (lsp.lua), so conform owns html
        html = { "prettierd", "prettier", stop_after_first = true },
        -- api-mono's tox.ini `fix` target (every service) is plain `black`, and
        -- setup.cfg's flake8 never sorts imports (no isort, no ruff anywhere in
        -- the repo) — ruff_organize_imports has no counterpart there and would
        -- reorder unrelated imports on every save. Everywhere else keeps ruff,
        -- which is what those repos actually run.
        python = vim.g.gaf and { "black" } or { "ruff_organize_imports", "ruff_format" },
        dart = { "dart_format" },
        rust = { "rustfmt" },
        swift = { "swiftformat" },
      }
      local formatters = {
        -- This config's Lua is hand-formatted (2-space, mixed one-liners) and
        -- stylua's defaults clobber it. Only run stylua in projects that opt
        -- in with a stylua config file; elsewhere lua saves are left alone
        -- (no lua LSP is set up, so the lsp fallback below is a no-op too).
        -- No pyproject.toml anywhere in api-mono, so black falls back to its own
        -- default (88) instead of the 119 every service's setup.cfg lints to —
        -- confirmed against the real column widths of committed files, not just
        -- the ignored-E501 comment. Without this, black wraps lines that were
        -- never too long to begin with.
        black = { prepend_args = { "--line-length", "119" } },
        stylua = {
          condition = function(_, ctx)
            return #vim.fs.find({ ".stylua.toml", "stylua.toml" }, { path = ctx.dirname, upward = true }) > 0
          end,
        },
      }
      if vim.g.gaf then
        formatters_by_ft.php = { "php_cs_fixer" }
        formatters.php_cs_fixer = require("gaf.formatting").php_cs_fixer_formatter()
      else
        -- Laravel: pint for php, blade-formatter for views. Both are
        -- condition-guarded on the project shipping the tool (see
        -- lua/artisan/formatting.lua), so a plain PHP repo is left to the
        -- lsp_format fallback below rather than being restyled to Laravel's
        -- ruleset by a globally-installed pint.
        local laravel_fmt = require("artisan.formatting")
        formatters_by_ft = vim.tbl_deep_extend("force", formatters_by_ft, laravel_fmt.formatters_by_ft())
        formatters = vim.tbl_deep_extend("force", formatters, laravel_fmt.formatters())
      end
      -- Merge into the accumulated opts (rails.lua's conform spec adds ruby/eruby);
      -- returning a fresh table here would drop theirs if lazy ever resolved this
      -- spec after them.
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, formatters_by_ft)
      opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, formatters)
      opts.format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        -- 3s: rubocop --server cold start and php-cs-fixer overrun the 500ms
        -- default. lsp fallback covers fts with no conform entry (json/yaml/…).
        return { timeout_ms = 3000, lsp_format = "fallback" }
      end
      return opts
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      if vim.g.gaf then
        local phpcs = lint.linters.phpcs
        -- Absolute path: a cwd-relative "./vendor/bin/phpcs" broke lint (spawn
        -- error on every save) whenever nvim wasn't started from the fl-gaf root.
        phpcs.cmd = require("gaf.paths").fl_gaf .. "/vendor/bin/phpcs"
        -- Both rulesets set `installed_paths` to *cwd-relative* vendor paths, so
        -- phpcs run from anywhere else exits with `Referenced sniff
        -- "GAFCodingStandard.Functions.TranslationUsage" does not exist` — plain
        -- text on stdout, which then blows up the JSON parser. Pinning cwd also
        -- makes the repo-relative --stdin-path below resolve.
        phpcs.cwd = require("gaf.paths").fl_gaf
        phpcs.args = require("gaf.formatting").phpcs_args()
        -- Re-grade phpcs output through .arclint's per-sniff severity map, so
        -- the buffer agrees with `arc lint` about what actually blocks.
        phpcs.parser = require("gaf.formatting").phpcs_parser(phpcs.parser)
        lint.linters_by_ft = { php = { "phpcs" } }
      else
        lint.linters_by_ft = {}
        -- phpstan/larastan is dispatched per buffer in the autocmd below rather
        -- than declared here: eligibility depends on the buffer's own project
        -- (artisan root + vendor/bin/phpstan + phpstan.neon), and
        -- linters_by_ft is global.
        require("artisan.lint").configure(lint)
      end

      -- Guarded: try_lint on every save would spam spawn errors if the
      -- binary is missing (same failure mode as the phpcs note above).
      if vim.fn.executable("swiftlint") == 1 then
        lint.linters_by_ft.swift = { "swiftlint" }
      end

      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("lint", { clear = true }),
        callback = function(args)
          -- php outside GAF is project-dependent: run phpstan only where the
          -- buffer's own project can actually support it. try_lint(nil) would
          -- fall back to linters_by_ft, which has no php entry here.
          if not vim.g.gaf and vim.bo[args.buf].filetype == "php" then
            local names = require("artisan.lint").php_linters(args.buf)
            if #names > 0 then lint.try_lint(names) end
            return
          end
          -- .arclint excludes some PHP from phpcs entirely (support/flarc is
          -- PHP 7.4 and would fail the 8.1 PHPCompatibility sniffs; the phpstan
          -- baselines are excluded repo-wide). nvim-lint has no per-linter
          -- condition, so the exclusion belongs here.
          if vim.g.gaf and vim.bo[args.buf].filetype == "php" then
            local paths = require("gaf.paths")
            if not require("gaf.arclint").phpcs_applies(paths.gaf_relpath(args.buf)) then return end
          end
          lint.try_lint()
        end,
      })
    end,
  },
}
