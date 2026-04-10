return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- Adapters
      "olimorris/neotest-phpunit",
      "nvim-neotest/neotest-jest",
      "nvim-neotest/neotest-python",
    },
    keys = {
      { "<leader>Tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>Tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>Ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
      { "<leader>To", function() require("neotest").output.open({ enter_on_run = true }) end, desc = "Show output" },
      { "<leader>TO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>Td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
      { "<leader>Tl", function() require("neotest").run.run_last() end, desc = "Run last test" },
      { "<leader>TS", function() require("neotest").run.stop() end, desc = "Stop test" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-phpunit")({
            phpunit_cmd = function()
              -- Use neotest wrapper for fl-gaf projects (handles Docker infra via bin/run-tests)
              local cwd = vim.fn.getcwd()
              if cwd:match("fl%-gaf") and vim.fn.filereadable(cwd .. "/bin/run-tests") == 1 then
                return vim.fn.stdpath("config") .. "/scripts/neotest-run-tests.sh"
              end
              return "vendor/bin/phpunit"
            end,
          }),
          require("neotest-jest")({
            jestCommand = "npx jest",
          }),
          require("neotest-python")({
            dap = { justMyCode = false },
          }),
        },
        discovery = {
          enabled = false,
        },
        status = {
          virtual_text = true,
          signs = true,
        },
        output = {
          open_on_run = "short",
        },
      })
    end,
  },
}
