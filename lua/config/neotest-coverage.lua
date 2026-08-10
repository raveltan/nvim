local M = {}

local last = nil

local function find_project_root(path, markers)
  local found = vim.fs.find(markers, { upward = true, path = vim.fs.dirname(path) })[1]
  if found then return vim.fs.dirname(found) end
  return vim.fn.getcwd()
end

-- Rust does not go through neotest. rustaceanvim's neotest adapter builds its
-- spec as `{ command = ... }` with no env field and never reads args.env, so
-- the instrumentation vars neotest.run.run would carry are dropped on the
-- floor — and cargo-llvm-cov needs more than a flag anyway (RUSTFLAGS
-- -C instrument-coverage, LLVM_PROFILE_FILE, a separate report step). Driving
-- `cargo llvm-cov` directly does the build, the run and the lcov report in one
-- command.
local function run_rust(file)
  if vim.fn.executable("cargo-llvm-cov") == 0 then
    return vim.notify("cargo-llvm-cov not installed (cargo install cargo-llvm-cov)", vim.log.levels.WARN)
  end
  local root = find_project_root(file, { "Cargo.toml", ".git" })
  local coverage_rel = "coverage/lcov.info"
  local coverage_file = root .. "/" .. coverage_rel

  vim.notify("Running cargo llvm-cov (instrumented rebuild, this is slow)...", vim.log.levels.INFO)
  vim.system(
    { "cargo", "llvm-cov", "--all-features", "--workspace", "--lcov", "--output-path", coverage_rel },
    { cwd = root, text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        local err = (res.stderr or ""):gsub("%s+$", "")
        return vim.notify("cargo llvm-cov failed:\n" .. err, vim.log.levels.ERROR)
      end
      if not vim.uv.fs_stat(coverage_file) then
        return vim.notify("cargo llvm-cov wrote no " .. coverage_rel, vim.log.levels.WARN)
      end
      pcall(vim.cmd, "CoverageLoadLcov " .. vim.fn.fnameescape(coverage_file))
      pcall(vim.cmd, "CoverageShow")
      vim.notify("Coverage loaded: " .. coverage_rel, vim.log.levels.INFO)
    end)
  )
end

function M.run(file, ft)
  local run_env, coverage_rel, markers, extra_args
  -- Set for a Pest project: pest needs its coverage flags threaded through
  -- `pest_cmd` rather than through neotest, and the target has to be cleared
  -- again once this run settles. See the pest branch below.
  local pest = false
  if ft == "php" then
    coverage_rel = "coverage/cobertura.xml"
    -- NEOTEST_COVERAGE is read only by scripts/neotest-run-tests.sh, the GAF
    -- phpunit wrapper. neotest-pest's build_spec ignores env, extra_args and cwd
    -- outright, so for Pest this variable does nothing at all.
    run_env = { NEOTEST_COVERAGE = "1" }
    markers = { "bin/run-tests", "composer.json", ".git" }
    pest = not vim.g.gaf
      and require("artisan.test").is_pest_root(require("artisan").root(vim.fs.dirname(file)))
    if pest then
      local ok, reason = require("artisan.test").coverage_available()
      if not ok then
        return vim.notify(reason, vim.log.levels.WARN)
      end
    end
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
  elseif ft == "dart" then
    coverage_rel = "coverage/lcov.info"
    run_env = nil
    markers = { "pubspec.yaml", ".git" }
    extra_args = { "--coverage" }
  elseif ft == "rust" then
    last = { file = file, ft = ft }
    return run_rust(file)
  else
    vim.notify("Coverage not configured for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  last = { file = file, ft = ft }

  local root = find_project_root(file, markers)
  local coverage_file = root .. "/" .. coverage_rel

  -- Fingerprint with nsec + size too: a rewrite within the same wall-clock
  -- second as this stat would otherwise look unchanged and the poll below
  -- would run to timeout.
  local function fingerprint(s)
    if not s then return "" end
    return s.mtime.sec .. ":" .. s.mtime.nsec .. ":" .. s.size
  end
  local prev_fp = fingerprint(vim.uv.fs_stat(coverage_file))

  if pest then require("artisan.test").set_coverage(coverage_file) end
  local function done()
    if pest then require("artisan.test").set_coverage(nil) end
  end

  vim.notify("Running test with coverage...", vim.log.levels.INFO)
  local ok = pcall(require("neotest").run.run, { file, env = run_env, extra_args = extra_args })
  if not ok then
    done()
    return vim.notify("Coverage run failed to start", vim.log.levels.ERROR)
  end

  local elapsed_ms = 0
  local interval_ms = 1000
  -- Pest writes its report as the run finishes, so a short ceiling is enough and
  -- keeps a missing driver from looking like a hang. The other toolchains here
  -- can genuinely take minutes on a cold cache.
  local timeout_ms = pest and 180000 or 600000
  local timer = vim.uv.new_timer()
  timer:start(interval_ms, interval_ms, vim.schedule_wrap(function()
    elapsed_ms = elapsed_ms + interval_ms
    local s = vim.uv.fs_stat(coverage_file)
    if s and fingerprint(s) ~= prev_fp then
      timer:stop(); timer:close()
      done()
      pcall(vim.cmd, "CoverageLoad")
      pcall(vim.cmd, "CoverageShow")
      vim.notify("Coverage loaded: " .. coverage_rel, vim.log.levels.INFO)
      return
    end
    if elapsed_ms >= timeout_ms then
      timer:stop(); timer:close()
      done()
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
