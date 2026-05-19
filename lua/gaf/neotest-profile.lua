-- Run neotest with xdebug profiling enabled.
-- XDEBUG_MODE=profile triggers bin/gaf-php (unit/script runs).
-- NEOTEST_PROFILE=1 makes scripts/neotest-run-tests.sh append --profile for bin/run-tests.

local M = {}

local last = nil

local function is_php_project(file)
  if vim.bo.filetype == "php" then return true end
  local dir = vim.fs.dirname(file)
  return vim.fs.find({ "bin/run-tests", "composer.json" },
    { upward = true, path = dir })[1] ~= nil
end

function M.run(file)
  if not is_php_project(file) then
    vim.notify("neotest-profile: only PHP projects supported", vim.log.levels.WARN)
    return
  end
  last = { file = file }
  local env = { XDEBUG_MODE = "profile", NEOTEST_PROFILE = "1" }
  vim.notify("Running test with xdebug profile mode...", vim.log.levels.INFO)
  require("neotest").run.run({ file, env = env })
  vim.notify(
    "Profile run started. After completion: :GafXdebugProfileList then " ..
    ":GafXdebugProfileDownload, :GafXdebugProfileOpen",
    vim.log.levels.INFO)
end

function M.run_current()
  M.run(vim.fn.expand("%:p"))
end

function M.run_last()
  if not last then
    vim.notify("No previous profile run to replay", vim.log.levels.WARN)
    return
  end
  M.run(last.file)
end

return M
