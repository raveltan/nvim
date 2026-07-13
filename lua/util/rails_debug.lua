-- Start `bin/rails server` under rdbg and attach nvim-dap in one go.
-- :RailsDebug (<leader>dR) starts the server and attaches when rdbg's debug
-- socket comes up; run it again to re-attach after a detach. :RailsDebugStop
-- disconnects and kills the server. Port matches nvim-dap-ruby's builtin
-- "attach existing (port 38698)" config, so manual attach also works.

local M = {}

local PORT = 38698

local state = { job = nil }

local function rails_root()
  local buf = vim.api.nvim_buf_get_name(0)
  local from = buf ~= "" and vim.fs.dirname(buf) or vim.fn.getcwd()
  return vim.fs.root(from, "bin/rails")
end

local function attach()
  require("dap").run({
    type = "ruby",
    name = ("attach rails server (:%d)"):format(PORT),
    request = "attach",
    port = PORT,
    waiting = 0,
    localfs = true,
    options = { source_filetype = "ruby" },
    error_on_failure = true,
  })
end

function M.start()
  if state.job then
    vim.notify("RailsDebug: server already running — re-attaching", vim.log.levels.INFO)
    attach()
    return
  end

  local root = rails_root()
  if not root then
    vim.notify("RailsDebug: no bin/rails found upward from buffer/cwd", vim.log.levels.ERROR)
    return
  end

  -- Force-load dap now so nvim-dap-ruby registers the ruby adapter before we attach.
  require("dap")

  local attached = false
  local function on_output(_, data)
    if not data then return end
    for _, line in ipairs(data) do
      if line ~= "" then
        -- Mirror server output into the dap repl.
        pcall(function() require("dap.repl").append(line) end)
        -- rdbg announces its socket before rails finishes booting.
        if not attached
            and (line:find("Debugger can attach", 1, true)
              or line:find("wait for debugger connection", 1, true)) then
          attached = true
          vim.schedule(attach)
        end
      end
    end
  end

  vim.notify("RailsDebug: starting rails server under rdbg (:" .. PORT .. ")", vim.log.levels.INFO)
  state.job = vim.fn.jobstart({
    "bundle", "exec", "rdbg",
    "-n",                       -- don't stop at program start
    "--open", "--port", tostring(PORT),
    "-c", "--", "bin/rails", "server",
  }, {
    cwd = root,
    on_stdout = on_output,
    on_stderr = on_output,
    on_exit = function(_, code)
      state.job = nil
      vim.schedule(function()
        vim.notify("RailsDebug: rails server exited (code " .. code .. ")",
          code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
      end)
    end,
  })
  if state.job <= 0 then
    state.job = nil
    vim.notify("RailsDebug: failed to spawn bundle/rdbg (in PATH? debug gem in Gemfile?)",
      vim.log.levels.ERROR)
    return
  end

  -- Fallback: rdbg version/format changes could rename the marker line —
  -- attach anyway after 15s while the server is still alive.
  vim.defer_fn(function()
    if state.job and not attached then
      attached = true
      attach()
    end
  end, 15000)
end

function M.stop()
  if package.loaded["dap"] then
    pcall(function() require("dap").disconnect({ terminateDebuggee = false }) end)
  end
  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
    vim.notify("RailsDebug: rails server stopped", vim.log.levels.INFO)
  else
    vim.notify("RailsDebug: no server running", vim.log.levels.INFO)
  end
end

return M
