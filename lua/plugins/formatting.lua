local in_freelancer = vim.fn.getcwd():find(vim.fn.expand("~/freelancer-dev"), 1, true) ~= nil

return {
  -- Formatting
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        php = in_freelancer and { "php_cs_fixer" } or { "pint" },
        blade = { "blade-formatter" },
      },
      formatters = in_freelancer and {
        pint = {
          command = function()
            local pint = vim.fn.getcwd() .. "/vendor/bin/pint"
            if vim.fn.executable(pint) == 1 then return pint end
            return "pint"
          end,
        },
        php_cs_fixer = {
          command = vim.fn.expand("~/freelancer-dev/fl-gaf/support/php-cs-fixer/vendor/bin/php-cs-fixer"),
          args = {
            "fix",
            "--config=" .. vim.fn.expand("~/freelancer-dev/fl-gaf/.php-cs-fixer.dist.php"),
            "--no-interaction",
            "--quiet",
            "$FILENAME",
          },
          stdin = false,
        },
      } or {},
      format_on_save = function()
        if vim.g.disable_autoformat then return end
        return { timeout_ms = 3000, lsp_format = "fallback" }
      end,
    },
  },

  -- Linting
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      if in_freelancer then
        local phpcs = lint.linters.phpcs
        phpcs.cmd = "./vendor/bin/phpcs"
        phpcs.args = {
          "-q",
          "--report=json",
          "--standard=" .. vim.fn.expand("~/freelancer-dev/fl-gaf/phpcs_gaf.xml"),
          "-",
        }

        local phpstan = lint.linters.phpstan
        phpstan.cmd = "./vendor/bin/phpstan"
        phpstan.args = {
          "analyse",
          "--no-progress",
          "--error-format=json",
          "--memory-limit=512M",
          "--no-ansi",
          "--no-interaction",
          "--configuration=" .. vim.fn.expand("~/freelancer-dev/fl-gaf/phpstan.neon"),
        }
      end

      lint.linters_by_ft = in_freelancer and {
        php = { "phpcs", "phpstan" },
      } or {}

      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("lint", { clear = true }),
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
