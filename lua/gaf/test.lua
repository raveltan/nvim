-- GAF neotest extensions:
--   * neotest-ui-tests adapter (webapp UI specs)
--   * scripts/neotest-run-tests.sh phpunit wrapper for Docker test infra
--   * <leader>tx/tX setup/shutdown infra (PHP buffers)
--   * <leader>tm/tw mobile/watch flags (UI-test buffers)
--   * <leader>tp/tP profile a test with xdebug profile mode (TIME)
--   * <leader>dD toggle GAF_DEBUG env
-- Memory profiling for local functional tests is NOT supported because
-- bin/gaf-php only handles XDEBUG_MODE=debug|profile|coverage (no trace branch).
-- For memory: profile HTTP endpoints against devbox via <leader>Xm instead.

local M = {}

local infra = require("gaf.test_infra")

function M.extend(opts)
  -- phpunit_cmd is already GAF-aware in plugins/test.lua; only the UI-test
  -- adapter needs adding here.
  table.insert(opts.adapters, 1, require("gaf.neotest-ui-tests"))
end

function M.attach_keys(buf, filetype)
  if filetype == "php" then
    local o = { buffer = buf, silent = true }
    vim.keymap.set("n", "<leader>tp", function() require("gaf.neotest-profile").run_current() end,
      vim.tbl_extend("force", o, { desc = "Profile file tests TIME (xdebug profile)" }))
    vim.keymap.set("n", "<leader>tx", infra.setup_infra,
      vim.tbl_extend("force", o, { desc = "Setup test infra" }))
    vim.keymap.set("n", "<leader>tX", infra.shutdown_infra,
      vim.tbl_extend("force", o, { desc = "Shutdown test infra" }))
  end
end

function M.setup_autocmds()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("gaf_uitest_keys", { clear = true }),
    pattern = "*/ui-tests/src/*.spec.ts",
    callback = function(ev)
      -- BufEnter refires on every buffer switch; map once per buffer.
      if vim.b[ev.buf].gaf_uitest_keys then return end
      vim.b[ev.buf].gaf_uitest_keys = true
      local o = { buffer = ev.buf }
      vim.keymap.set("n", "<leader>tm", function()
        require("neotest").run.run({ extra_args = { "--mobile" } })
      end, vim.tbl_extend("force", o, { desc = "Run test (mobile)" }))
      vim.keymap.set("n", "<leader>tw", function()
        require("neotest").run.run({ extra_args = { "--watch" } })
      end, vim.tbl_extend("force", o, { desc = "Run test (watch)" }))
    end,
  })
end

return M
