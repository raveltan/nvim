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
    },
    -- No ft trigger: loading neotest + 7 adapters cost ~68ms on the FIRST buffer
    -- of any daily filetype, every session. The buffer-local keymaps that needed
    -- it live in config/autocmds.lua now; pressing one lazy-loads neotest via
    -- lazy.nvim's module autoloader on require("neotest").
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
        -- Re-runs whichever profiler ran last: ruby stackprof or GAF xdebug
        -- (both register via config.profile.remember).
        { "<leader>tP", function() require("config.profile").run_last() end, desc = "Profile last test" },
      }
      return keys
    end,
    opts = function()
      local opts = {
        adapters = {
          -- GAF: scripts/neotest-run-tests.sh wraps bin/run-tests (Docker infra);
          -- built once here instead of being rebuilt in gaf.test.extend().
          require("neotest-phpunit")({
            phpunit_cmd = vim.g.gaf
                and (vim.fn.stdpath("config") .. "/scripts/neotest-run-tests.sh")
              or "vendor/bin/phpunit",
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
        },
        discovery = { enabled = false },
        status = { virtual_text = true, signs = true },
        output = { open_on_run = "short" },
      }
      -- Flutter/Dart: only register neotest-dart on actual Flutter projects
      -- (pubspec.yaml in cwd or a parent), not in every session.
      if vim.fn.findfile("pubspec.yaml", ".;") ~= "" then
        table.insert(opts.adapters, require("neotest-dart")({
          command = "flutter",
          use_lsp = true,
        }))
      end
      -- Rust: rustaceanvim ships its own neotest adapter (replaces the archived
      -- rouge8/neotest-rust). Register only on actual Cargo projects. requiring
      -- the module pulls in rustaceanvim, which owns rust-analyzer + test exec;
      -- pcall-guard so a non-rust session never hard-errors on the require.
      if vim.fn.findfile("Cargo.toml", ".;") ~= "" then
        local ok, rust_adapter = pcall(require, "rustaceanvim.neotest")
        if ok then table.insert(opts.adapters, rust_adapter) end
      end
      return opts
    end,
    init = function()
      if vim.g.gaf then require("gaf.test").setup_autocmds() end
    end,
    config = function(_, opts)
      if vim.g.gaf then require("gaf.test").extend(opts) end
      require("neotest").setup(opts)
    end,
  },
}
