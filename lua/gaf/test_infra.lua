-- bin/run-tests setup/shutdown helpers for fl-gaf Docker test infrastructure.
-- shutdown reads cached worker IDs from .cache/gaf_session_* so per-session
-- Docker stacks tear down cleanly.

local M = {}

local function find_root()
  local dir = vim.fn.getcwd()
  while dir ~= "/" do
    if vim.fn.executable(dir .. "/bin/run-tests") == 1 then return dir end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

function M.setup_infra()
  local dir = find_root()
  if not dir then
    vim.notify("No bin/run-tests found", vim.log.levels.WARN)
    return
  end
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
end

function M.shutdown_infra()
  local dir = find_root()
  if not dir then
    vim.notify("No bin/run-tests found", vim.log.levels.WARN)
    return
  end

  local session_files = vim.fn.glob(dir .. "/.cache/gaf_session_*", false, true)
  local worker_ids = {}
  for _, f in ipairs(session_files) do
    local id = vim.fn.trim(vim.fn.readfile(f)[1] or "")
    if id ~= "" then table.insert(worker_ids, id) end
  end

  local function shutdown_one(worker_id, done)
    local env = worker_id and { GAF_TEST_WORKER_ID = worker_id } or nil
    vim.fn.jobstart({ dir .. "/bin/run-tests", "shutdown" }, {
      cwd = dir,
      env = env,
      on_exit = function(_, code) done(worker_id, code) end,
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
    return
  end

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

function M.toggle_debug_flag()
  vim.g.gaf_test_debug = not vim.g.gaf_test_debug
  if vim.g.gaf_test_debug then
    vim.env.GAF_DEBUG = "1"
    vim.notify("GAF_DEBUG=1 (next neotest run will pass --debug)", vim.log.levels.INFO)
  else
    vim.env.GAF_DEBUG = nil
    vim.notify("GAF_DEBUG cleared", vim.log.levels.INFO)
  end
end

return M
