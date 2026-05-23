local M = {}

local last = nil

local function find_project_root(path, markers)
  local found = vim.fs.find(markers, { upward = true, path = vim.fs.dirname(path) })[1]
  if found then return vim.fs.dirname(found) end
  return vim.fn.getcwd()
end

function M.run(file, ft)
  local run_env, coverage_rel, markers, extra_args
  if ft == "php" then
    coverage_rel = "coverage/cobertura.xml"
    run_env = { NEOTEST_COVERAGE = "1" }
    markers = { "bin/run-tests", "composer.json", ".git" }
  elseif ft == "ruby" then
    coverage_rel = "coverage/.resultset.json"
    run_env = nil
    markers = { "Gemfile", "Rakefile", ".git" }
  elseif ft == "typescript" or ft == "javascript" then
    coverage_rel = "coverage/lcov.info"
    run_env = nil
    markers = { "package.json", ".git" }
    extra_args = { "--coverage" }
  elseif ft == "python" then
    coverage_rel = "coverage.xml"
    run_env = nil
    markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }
    extra_args = { "--cov", "--cov-report=xml" }
  elseif ft == "rust" then
    -- Requires cargo-llvm-cov installed. The neotest-rust adapter shells out to
    -- `cargo test`; setting CARGO env vars makes llvm-cov instrument the build
    -- and dump lcov to coverage/lcov.info on test exit.
    coverage_rel = "coverage/lcov.info"
    run_env = {
      CARGO_LLVM_COV = "1",
      CARGO_LLVM_COV_TARGET_DIR = "target/llvm-cov-target",
      LLVM_COV_FLAGS = "--lcov --output-path=coverage/lcov.info",
    }
    markers = { "Cargo.toml", ".git" }
  else
    vim.notify("Coverage not configured for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  last = { file = file, ft = ft }

  local root = find_project_root(file, markers)
  local coverage_file = root .. "/" .. coverage_rel

  local prev_mtime = 0
  local stat = vim.uv.fs_stat(coverage_file)
  if stat then prev_mtime = stat.mtime.sec end

  vim.notify("Running test with coverage...", vim.log.levels.INFO)
  require("neotest").run.run({ file, env = run_env, extra_args = extra_args })

  local elapsed_ms = 0
  local interval_ms = 1000
  local timeout_ms = 600000
  local timer = vim.uv.new_timer()
  timer:start(interval_ms, interval_ms, vim.schedule_wrap(function()
    elapsed_ms = elapsed_ms + interval_ms
    local s = vim.uv.fs_stat(coverage_file)
    if s and s.mtime.sec ~= prev_mtime then
      timer:stop(); timer:close()
      pcall(vim.cmd, "CoverageLoad")
      pcall(vim.cmd, "CoverageShow")
      vim.notify("Coverage loaded: " .. coverage_rel, vim.log.levels.INFO)
      return
    end
    if elapsed_ms >= timeout_ms then
      timer:stop(); timer:close()
      vim.notify("Coverage poll timed out (" .. coverage_rel .. " not updated)", vim.log.levels.WARN)
    end
  end))
end

function M.run_current()
  M.run(vim.fn.expand("%:p"), vim.bo.filetype)
end

function M.run_last()
  if not last then
    vim.notify("No previous coverage run to replay", vim.log.levels.WARN)
    return
  end
  M.run(last.file, last.ft)
end

return M
