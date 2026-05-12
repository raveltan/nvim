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
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-python",
      "olimorris/neotest-rspec",
      "zidhuss/neotest-minitest",
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
    ft = { "php", "typescript", "javascript", "python", "ruby" },
    opts = function()
      local ui_tests_adapter = require("config.neotest-ui-tests")
      return {
        adapters = {
          ui_tests_adapter,
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
            isTestFile = function(file_path)
              -- Exclude webapp UI test specs — those are handled by neotest-ui-tests
              if file_path:match("ui%-tests/src/.+%.spec%.ts$") then
                return false
              end
              return file_path:match("%.test%.[jt]sx?$") or file_path:match("%.spec%.[jt]sx?$")
            end,
          }),
          require("neotest-vitest")({
            -- Only claim vitest specs so jest/ui-tests adapters still match their own patterns
            filter_dir = function(name, _, _)
              return name ~= "node_modules" and name ~= "ui-tests"
            end,
            is_test_file = function(file_path)
              if file_path:match("ui%-tests/src/.+%.spec%.ts$") then
                return false
              end
              if not (file_path:match("%.test%.[jt]sx?$") or file_path:match("%.spec%.[jt]sx?$")) then
                return false
              end
              local dir = vim.fs.dirname(file_path)
              local pkg = vim.fs.find("package.json", { upward = true, path = dir })[1]
              if not pkg then return false end
              local ok, contents = pcall(vim.fn.readfile, pkg)
              if not ok then return false end
              return table.concat(contents, "\n"):match("vitest") ~= nil
            end,
          }),
          require("neotest-python")({
            dap = { justMyCode = false },
          }),
          require("neotest-rspec")({
            rspec_cmd = { "bundle", "exec", "rspec" },
          }),
          require("neotest-minitest")({
            test_cmd = { "bundle", "exec", "rails", "test" },
          }),
        },
        discovery = { enabled = false },
        status = { virtual_text = true, signs = true },
        output = { open_on_run = "short" },
      }
    end,
    config = function(_, opts)
      -- Context-aware buffer-local keybindings
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*/ui-tests/src/*.spec.ts",
        callback = function(ev)
          local o = { buffer = ev.buf }
          vim.keymap.set("n", "<leader>Tm", function()
            require("neotest").run.run({ extra_args = { "--mobile" } })
          end, vim.tbl_extend("force", o, { desc = "Run test (mobile)" }))
          vim.keymap.set("n", "<leader>Tw", function()
            require("neotest").run.run({ extra_args = { "--watch" } })
          end, vim.tbl_extend("force", o, { desc = "Run test (watch)" }))
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "php",
        callback = function(ev)
          local cwd = vim.fn.getcwd()
          if not cwd:match("fl%-gaf") then return end
          vim.keymap.set("n", "<leader>Tx", function()
            local dir = cwd
            while dir ~= "/" do
              if vim.fn.executable(dir .. "/bin/run-tests") == 1 then
                vim.notify("Setting up test infrastructure...", vim.log.levels.INFO)
                vim.fn.jobstart({ dir .. "/bin/run-tests", "setup" }, {
                  cwd = dir,
                  on_exit = function(_, code)
                    if code == 0 then
                      vim.notify("Test infrastructure ready", vim.log.levels.INFO)
                    else
                      vim.notify("Test setup failed (exit " .. code .. ")", vim.log.levels.ERROR)
                    end
                  end,
                })
                return
              end
              dir = vim.fn.fnamemodify(dir, ":h")
            end
            vim.notify("No bin/run-tests found", vim.log.levels.WARN)
          end, { buffer = ev.buf, desc = "Setup test infra" })

          vim.keymap.set("n", "<leader>TX", function()
            local dir = cwd
            while dir ~= "/" do
              if vim.fn.executable(dir .. "/bin/run-tests") == 1 then
                local session_files = vim.fn.glob(dir .. "/.cache/gaf_session_*", false, true)
                local worker_ids = {}
                for _, f in ipairs(session_files) do
                  local id = vim.fn.trim(vim.fn.readfile(f)[1] or "")
                  if id ~= "" then table.insert(worker_ids, id) end
                end

                local function shutdown_one(worker_id, done)
                  local env = nil
                  if worker_id then env = { GAF_TEST_WORKER_ID = worker_id } end
                  vim.fn.jobstart({ dir .. "/bin/run-tests", "shutdown" }, {
                    cwd = dir,
                    env = env,
                    on_exit = function(_, code)
                      done(worker_id, code)
                    end,
                  })
                end

                if #worker_ids == 0 then
                  vim.notify("Tearing down test infrastructure...", vim.log.levels.INFO)
                  shutdown_one(nil, function(_, code)
                    if code == 0 then
                      vim.notify("Test infrastructure torn down", vim.log.levels.INFO)
                    else
                      vim.notify("Test shutdown failed (exit " .. code .. ")", vim.log.levels.ERROR)
                    end
                  end)
                else
                  vim.notify("Tearing down " .. #worker_ids .. " test session(s)...", vim.log.levels.INFO)
                  local remaining = #worker_ids
                  local failed = {}
                  for _, wid in ipairs(worker_ids) do
                    shutdown_one(wid, function(id, code)
                      if code ~= 0 then table.insert(failed, id) end
                      remaining = remaining - 1
                      if remaining == 0 then
                        if #failed == 0 then
                          vim.notify("All test sessions torn down", vim.log.levels.INFO)
                        else
                          vim.notify("Shutdown failed for: " .. table.concat(failed, ", "), vim.log.levels.ERROR)
                        end
                      end
                    end)
                  end
                end
                return
              end
              dir = vim.fn.fnamemodify(dir, ":h")
            end
            vim.notify("No bin/run-tests found", vim.log.levels.WARN)
          end, { buffer = ev.buf, desc = "Shutdown test infra" })
        end,
      })

      require("neotest").setup(opts)
    end,
  },
}
