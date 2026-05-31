return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "olimorris/neotest-phpunit",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-python",
      "olimorris/neotest-rspec",
      "zidhuss/neotest-minitest",
      "sidlatau/neotest-dart",
      "rouge8/neotest-rust",
    },
    ft = { "php", "typescript", "javascript", "python", "ruby", "dart", "rust" },
    keys = function()
      local keys = {
        { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run last test" },
        { "<leader>tL", function()
            require("dap") -- force-load so per-filetype dap.configurations are populated
            require("neotest").run.run_last({ strategy = "dap" })
        end, desc = "Debug last test" },
        { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop test" },
        { "<leader>to", function() require("neotest").output.open({ last_run = true, enter = true }) end, desc = "Show last output" },
        { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
        { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
        { "<leader>tM", function() require("neotest").summary.run_marked() end, desc = "Run marked tests" },
        { "<leader>tC", function() require("config.neotest-coverage").run_last() end, desc = "Run last test with coverage" },
        { "<leader>tP", function() require("config.profile").run_last() end, desc = "Profile last test" },
      }
      if vim.g.gaf then
        vim.list_extend(keys, require("gaf.test").global_keys())
      end
      return keys
    end,
    opts = function()
      return {
        adapters = {
          require("neotest-phpunit")({
            phpunit_cmd = "vendor/bin/phpunit",
          }),
          require("neotest-vitest")({
            filter_dir = function(name, _, _)
              return name ~= "node_modules" and name ~= "ui-tests"
            end,
            -- Filename match ONLY. neotest-vitest already AND-wraps this with its
            -- built-in hasVitestDependency() check, so re-reading package.json here
            -- was redundant — and broken: it ran *after* that check's async file
            -- read, where vim.fn.readfile errors in the nio callback context. The
            -- pcall swallowed the error → returned false → every test file was
            -- rejected ("no test found"). Drop it; keep only the name pattern.
            is_test_file = function(file_path)
              if file_path:match("ui%-tests/src/.+%.spec%.ts$") then
                return false
              end
              return file_path:match("%.test%.[mc]?[jt]sx?$") ~= nil
                or file_path:match("%.spec%.[mc]?[jt]sx?$") ~= nil
            end,
          }),
          require("neotest-python")({
            dap = { justMyCode = false },
          }),
          require("neotest-rspec")({
            rspec_cmd = function()
              if vim.fn.executable("bin/rspec") == 1 then
                return { "bin/rspec" }
              end
              return { "bundle", "exec", "rspec" }
            end,
            filter_dirs = { ".git", "node_modules", "vendor", "tmp", "coverage", "log" },
          }),
          require("neotest-minitest")({
            test_cmd = function()
              if vim.fn.filereadable("bin/rails") == 1 then
                return { "bin/rails", "test" }
              end
              return { "bundle", "exec", "ruby", "-Itest" }
            end,
          }),
          require("neotest-dart")({
            command = "flutter",
            use_lsp = true,
          }),
          require("neotest-rust")({
            args = { "--no-capture" },
          }),
        },
        discovery = { enabled = false },
        status = { virtual_text = true, signs = true },
        output = { open_on_run = "short" },
      }
    end,
    init = function()
      if vim.g.gaf then require("gaf.test").setup_autocmds() end
    end,
    config = function(_, opts)
      if vim.g.gaf then require("gaf.test").extend(opts) end

      local test_filetypes = { "php", "typescript", "javascript", "python", "ruby", "dart", "rust" }

      local function attach_test_keys(buf, ft)
        local o = { buffer = buf, silent = true }
        vim.keymap.set("n", "<leader>tr", function() require("neotest").run.run() end, vim.tbl_extend("force", o, { desc = "Run nearest test" }))
        vim.keymap.set("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, vim.tbl_extend("force", o, { desc = "Run file tests" }))
        vim.keymap.set("n", "<leader>tc", function() require("config.neotest-coverage").run_current() end, vim.tbl_extend("force", o, { desc = "Run file tests with coverage" }))
        vim.keymap.set("n", "<leader>td", function()
          require("dap") -- force-load so per-filetype dap.configurations are populated
          require("neotest").run.run({ strategy = "dap" })
        end, vim.tbl_extend("force", o, { desc = "Debug nearest test" }))
        if ft == "ruby" then
          vim.keymap.set("n", "<leader>tp", function() require("config.neotest-profile-ruby").run_current() end,
            vim.tbl_extend("force", o, { desc = "Profile file tests (stackprof)" }))
        end
        if vim.g.gaf then require("gaf.test").attach_keys(buf, ft) end
      end
      vim.api.nvim_create_autocmd("FileType", {
        pattern = test_filetypes,
        callback = function(ev) attach_test_keys(ev.buf, ev.match) end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          local ft = vim.bo[buf].filetype
          if vim.tbl_contains(test_filetypes, ft) then attach_test_keys(buf, ft) end
        end
      end

      require("neotest").setup(opts)
    end,
  },
}
