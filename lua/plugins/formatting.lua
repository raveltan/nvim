return {
  -- Manual formatting via <leader>cf — no format-on-save.
  {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format file" },
    },
    opts = function()
      local formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        python = { "ruff_organize_imports", "ruff_format" },
        dart = { "dart_format" },
        rust = { "rustfmt" },
      }
      local formatters = {}
      if vim.g.gaf then
        formatters_by_ft.php = { "php_cs_fixer" }
        formatters.php_cs_fixer = require("gaf.formatting").php_cs_fixer_formatter()
      end
      return { formatters_by_ft = formatters_by_ft, formatters = formatters }
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      if vim.g.gaf then
        local phpcs = lint.linters.phpcs
        phpcs.cmd = "./vendor/bin/phpcs"
        phpcs.args = require("gaf.formatting").phpcs_args()
        lint.linters_by_ft = { php = { "phpcs" } }
      else
        lint.linters_by_ft = {}
      end

      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("lint", { clear = true }),
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
