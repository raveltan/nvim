-- webclient: the shared connection to one Chrome tab via the `webconnect` Go
-- bridge. Owns the single job/process, parses its NDJSON stdout, and fans
-- events out to registered panel handlers (console / network / storage all
-- share THIS connection). Also owns launch/build lifecycle.
--
-- Panels use:
--   client.on(type, fn)   register an event handler
--   client.send(tbl)      send a command (json + newline)
--   client.ensure(fn)     run fn once connected (starting the job if needed)
--   client.enable(domain) lazily enable a CDP domain ("network", "dom_storage")

local M = {}

local config = {
  host = "127.0.0.1",
  port = 9222,
  filter = "", -- substring of tab URL/title to attach to; "" = first page

  -- :ChromeLaunch settings (macOS defaults)
  chrome = nil, -- path to Chrome binary; nil = auto-detect
  user_data_dir = vim.fn.expand("~/.chrome-debug"),
  source_profile = vim.fn.expand("~/Library/Application Support/Google/Chrome"),
  extra_args = {},
}

local state = {
  job = nil,
  ready = false,
  partial = "",
  handlers = {}, -- event type -> { fn, ... }
  ready_queue = {}, -- fns to run on next "ready"
  enabled = {}, -- domain -> true (deduped per connection)
  attached = { title = "", target = "" }, -- cached from last "ready" event
  user_stop = false, -- true when the last stop was user-initiated (no reconnect)
  pending_restart = nil, -- filter to (re)attach to after the current job exits
  gen = 0, -- incrementing job generation; guards stale on_exit closures
  last_warn = 0, -- last "not connected" warn time (throttling), in ms
  screenshot_registered = false, -- guard: screenshot handler registered once
}

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

function M.get_config()
  return config
end

function M.is_running()
  return state.job ~= nil
end

function M.is_ready()
  return state.ready
end

-- connection status: "off" (no job), "connecting" (job up, not ready yet), "ready"
function M.status()
  if not state.job then
    return "off"
  end
  return state.ready and "ready" or "connecting"
end

-- info about the currently-attached target, cached from the last "ready" event.
-- empty strings before the first ready.
function M.attached()
  return { title = state.attached.title, target = state.attached.target }
end

-- register an event handler. Multiple handlers per type are allowed.
function M.on(etype, fn)
  state.handlers[etype] = state.handlers[etype] or {}
  table.insert(state.handlers[etype], fn)
end

function M.send(tbl)
  if not state.job then
    local now = vim.loop.now()
    if now - state.last_warn > 2000 then
      state.last_warn = now
      vim.notify("webclient: not connected", vim.log.levels.WARN)
    end
    return false
  end
  vim.fn.chansend(state.job, vim.json.encode(tbl) .. "\n")
  return true
end

-- enable a CDP domain once per connection
function M.enable(domain)
  if state.enabled[domain] then
    return
  end
  state.enabled[domain] = true
  M.send({ op = "enable", domain = domain })
end

-- ── event plumbing ─────────────────────────────────────────────────────────

local function dispatch(ev)
  local hs = state.handlers[ev.type]
  if hs then
    for _, fn in ipairs(hs) do
      fn(ev)
    end
  end
end

local function on_event(ev)
  if ev.type == "ready" then
    state.ready = true
    state.enabled = {}
    state.attached = { title = ev.title or "", target = ev.target or "" }
    dispatch(ev)
    local q = state.ready_queue
    state.ready_queue = {}
    for _, fn in ipairs(q) do
      fn()
    end
    return
  elseif ev.type == "navigated" then
    -- a navigation invalidates the per-connection enabled-domain dedupe and any
    -- stale objectIds; panels subscribe and refetch themselves. Do NOT treat
    -- this as ready/closed.
    state.enabled = {}
    dispatch(ev)
    return
  elseif ev.type == "closed" then
    state.ready = false
  end
  dispatch(ev)
end

local function on_stdout(_, data)
  if not data then
    return
  end
  state.partial = state.partial .. data[1]
  for i = 2, #data do
    local line = state.partial
    state.partial = data[i]
    if line ~= "" then
      local ok, ev = pcall(vim.json.decode, line)
      if ok and type(ev) == "table" then
        vim.schedule(function() on_event(ev) end)
      end
    end
  end
end

-- run fn once connected; start the job if it isn't running yet
function M.ensure(fn)
  if state.ready then
    if fn then fn() end
    return
  end
  if fn then
    state.ready_queue[#state.ready_queue + 1] = fn
  end
  if not state.job then
    M.start()
  end
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

local function bin_path()
  return vim.fn.stdpath("config") .. "/webconnect/webconnect"
end

-- try to bring the connection back after an unexpected exit: poll the debug
-- port, then M.start(); up to a few attempts with backoff, then give up quietly.
local RECONNECT_TRIES = 3
local function reconnect(attempt)
  attempt = attempt or 1
  if state.job or state.user_stop then
    return -- already reconnected, or a user stop landed mid-backoff
  end
  if attempt > RECONNECT_TRIES then
    -- gave up: drop stale queued callbacks so they don't fire on a later connect.
    state.ready_queue = {}
    return
  end
  vim.notify("webclient: reconnecting… (" .. attempt .. "/" .. RECONNECT_TRIES .. ")", vim.log.levels.INFO)
  -- short port poll per attempt; on success start, otherwise back off and retry.
  -- (don't lean on wait_for_port's own give-up path so the backoff/queue-clear
  -- logic stays here.)
  local uv = vim.uv or vim.loop
  local sock = uv.new_tcp()
  sock:connect(config.host, config.port, function(err)
    sock:close()
    vim.schedule(function()
      if state.job or state.user_stop then
        return
      end
      if not err and M.start() then
        return
      end
      vim.defer_fn(function() reconnect(attempt + 1) end, 500 * attempt)
    end)
  end)
end

function M.start()
  if state.job then
    return true
  end
  local bin = bin_path()
  if vim.fn.executable(bin) == 0 then
    vim.notify("webclient: binary not built. Run :ChromeConsoleBuild", vim.log.levels.ERROR)
    return false
  end
  state.ready = false
  state.partial = ""
  state.enabled = {}
  state.user_stop = false

  local args = { bin, "-host", config.host, "-port", tostring(config.port) }
  if config.filter ~= "" then
    table.insert(args, "-filter")
    table.insert(args, config.filter)
  end

  state.gen = state.gen + 1
  local gen = state.gen

  state.job = vim.fn.jobstart(args, {
    on_stdout = on_stdout,
    on_stderr = function(_, d)
      if d and table.concat(d) ~= "" then
        vim.schedule(function() dispatch({ type = "stderr", text = table.concat(d, " ") }) end)
      end
    end,
    on_exit = function(_, code)
      -- only act if we're still the current job; a stale exit from a previously
      -- replaced job must not clobber a freshly-started one.
      if gen ~= state.gen then
        return
      end
      state.job = nil
      state.ready = false
      vim.schedule(function() dispatch({ type = "exit", code = code }) end)

      -- a pending restart (M.attach while a job was alive) takes priority over
      -- auto-reconnect: start the new job now that the old one has exited.
      if state.pending_restart ~= nil then
        local filter = state.pending_restart
        state.pending_restart = nil
        config.filter = filter
        vim.schedule(function() M.start() end)
        return
      end

      if not state.user_stop then
        vim.schedule(function() reconnect(1) end)
      end
    end,
  })
  if state.job <= 0 then
    state.job = nil
    vim.notify("webclient: failed to start webconnect", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.stop()
  state.user_stop = true
  if not state.job then
    return
  end
  M.send({ op = "quit" })
  vim.defer_fn(function()
    if state.job then
      vim.fn.jobstop(state.job)
    end
  end, 300)
end

-- list attachable targets via `webconnect -list`
function M.list_targets(cb)
  local bin = bin_path()
  if vim.fn.executable(bin) == 0 then
    vim.notify("webclient: binary not built (:ChromeConsoleBuild)", vim.log.levels.ERROR)
    return
  end
  local out = {}
  vim.fn.jobstart({ bin, "-host", config.host, "-port", tostring(config.port), "-list" }, {
    stdout_buffered = true,
    on_stdout = function(_, d)
      if d then
        for _, l in ipairs(d) do
          out[#out + 1] = l
        end
      end
    end,
    on_exit = function()
      vim.schedule(function()
        local ok, t = pcall(vim.json.decode, table.concat(out, "\n"))
        cb(ok and type(t) == "table" and t or {})
      end)
    end,
  })
end

-- attach to a specific target (by URL/title substring), restarting if needed.
-- when a job is alive we don't race a fixed timer against its shutdown: stash
-- the desired filter and let on_exit start the new job once the old one exits.
function M.attach(filter)
  filter = filter or ""
  if state.job then
    state.pending_restart = filter
    M.stop()
  else
    config.filter = filter
    M.start()
  end
end

-- pick a tab interactively and attach to it
function M.pick_tab()
  M.list_targets(function(targets)
    local pages = vim.tbl_filter(function(t) return t.type == "page" end, targets)
    if #pages == 0 then
      vim.notify("webclient: no page targets (is Chrome running on port " .. config.port .. "?)", vim.log.levels.WARN)
      return
    end
    vim.ui.select(pages, {
      prompt = "Attach to tab:",
      format_item = function(t)
        return (t.title ~= "" and t.title or "(untitled)") .. "  —  " .. t.url
      end,
    }, function(choice)
      if choice then
        vim.notify("webclient: attaching to " .. (choice.title ~= "" and choice.title or choice.url))
        M.attach(choice.url)
      end
    end)
  end)
end

-- kill whatever process is holding the debug port (a stale Chrome that blocks
-- a fresh launch), and clear the profile's singleton lock so a relaunch with
-- the same --user-data-dir won't report "profile in use". Runs cb when done.
function M.kill_port(cb)
  M.stop()
  local port = tostring(config.port)

  -- 1. kill the process holding the port (the listening socket)
  local pids = {}
  for _, p in ipairs(vim.fn.systemlist({ "lsof", "-nP", "-iTCP:" .. port, "-sTCP:LISTEN", "-t" })) do
    p = vim.trim(p)
    if p:match("^%d+$") then
      pids[#pids + 1] = p
    end
  end
  for _, pid in ipairs(pids) do
    vim.fn.system({ "kill", pid })
  end

  -- 2. also kill any Chrome launched with this debug port (catches instances
  --    lsof attributes late). pkill exits 1 when nothing matched — that's fine.
  vim.fn.system({ "pkill", "-f", "remote-debugging-port=" .. port })
  local matched = vim.v.shell_error == 0

  if #pids > 0 or matched then
    vim.notify("webclient: freed debug port " .. port, vim.log.levels.INFO)
  else
    vim.notify("webclient: nothing on port " .. port, vim.log.levels.INFO)
  end

  -- 3. clear the profile singleton lock so a relaunch isn't "profile in use"
  for _, f in ipairs({ "SingletonLock", "SingletonCookie", "SingletonSocket" }) do
    vim.fn.delete(config.user_data_dir .. "/" .. f)
  end

  if cb then
    vim.defer_fn(cb, 700)
  end
end

function M.reload()
  M.send({ op = "reload" })
end

function M.navigate(url)
  if url and url ~= "" then
    M.send({ op = "navigate", url = url })
  end
end

-- register the "screenshot" result handler exactly once.
local function register_screenshot_handler()
  if state.screenshot_registered then
    return
  end
  state.screenshot_registered = true
  M.on("screenshot", function(ev)
    if ev.ok and ev.path then
      vim.notify("webclient: screenshot saved → " .. ev.path, vim.log.levels.INFO)
    else
      vim.notify("webclient: screenshot failed: " .. (ev.error or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

-- capture a screenshot of the current tab; `full` = full-page (beyond viewport).
function M.screenshot(full)
  register_screenshot_handler()
  M.ensure(function()
    M.send({ op = "screenshot", full = full and true or false })
  end)
end

-- ── launch chrome with the debug port ─────────────────────────────────────

local CHROME_PATHS = {
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
}

local function chrome_bin()
  if config.chrome and vim.fn.executable(config.chrome) == 1 then
    return config.chrome
  end
  for _, p in ipairs(CHROME_PATHS) do
    if vim.fn.executable(p) == 1 then
      return p
    end
  end
  for _, name in ipairs({ "google-chrome", "chromium", "chrome" }) do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
  return nil
end

local function wait_for_port(tries, cb)
  local uv = vim.uv or vim.loop
  local function attempt(n)
    local sock = uv.new_tcp()
    sock:connect(config.host, config.port, function(err)
      sock:close()
      if not err then
        vim.schedule(cb)
      elseif n > 0 then
        vim.defer_fn(function() attempt(n - 1) end, 250)
      else
        vim.schedule(function()
          vim.notify("webclient: debug port " .. config.port .. " never came up", vim.log.levels.ERROR)
        end)
      end
    end)
  end
  attempt(tries)
end

local function spawn_chrome(opts, after)
  local bin = chrome_bin()
  if not bin then
    vim.notify("webclient: Chrome binary not found (set config.chrome)", vim.log.levels.ERROR)
    return
  end
  local args = {
    bin,
    "--remote-debugging-port=" .. config.port,
    "--user-data-dir=" .. config.user_data_dir,
    "--no-first-run",
    "--no-default-browser-check",
  }
  for _, a in ipairs(config.extra_args or {}) do
    table.insert(args, a)
  end
  if opts.url and opts.url ~= "" then
    table.insert(args, opts.url)
  end
  local job = vim.fn.jobstart(args, { detach = true })
  if job <= 0 then
    vim.notify("webclient: failed to spawn Chrome", vim.log.levels.ERROR)
    return
  end
  vim.notify("webclient: launching Chrome (port " .. config.port .. ")…", vim.log.levels.INFO)
  wait_for_port(40, after)
end

-- launch a debug-profile Chrome, then run opts.after.
-- opts.fresh = recopy profile; opts.url = open URL; opts.after = callback once port is up
function M.launch(opts)
  opts = opts or {}
  local after = opts.after or function() end

  local uv = vim.uv or vim.loop
  local probe = uv.new_tcp()
  probe:connect(config.host, config.port, function(err)
    probe:close()
    if not err then
      vim.schedule(function()
        vim.notify("webclient: debug port already up, connecting", vim.log.levels.INFO)
        after()
      end)
      return
    end
    vim.schedule(function() M._prepare_profile_and_spawn(opts, after) end)
  end)
end

-- launch a debug-profile Chrome AND connect the bridge, WITHOUT opening any panel
-- (console/network/storage). Just gets the connection live so panels can be opened
-- on demand. opts.fresh / opts.url forwarded to M.launch.
function M.launch_connect(opts)
  opts = opts or {}
  opts.after = function()
    if not M.is_running() then
      M.start()
    end
  end
  M.launch(opts)
end

function M._prepare_profile_and_spawn(opts, after)
  local dir = config.user_data_dir
  local exists = vim.fn.isdirectory(dir) == 1

  if opts.fresh and exists then
    vim.fn.delete(dir, "rf")
    exists = false
  end
  if exists then
    spawn_chrome(opts, after)
    return
  end
  if vim.fn.isdirectory(config.source_profile) == 0 then
    vim.notify("webclient: source profile not found, launching empty debug profile", vim.log.levels.WARN)
    spawn_chrome(opts, after)
    return
  end
  vim.notify("webclient: copying Chrome profile (first launch, may take a moment)…", vim.log.levels.INFO)
  vim.fn.jobstart({ "cp", "-R", config.source_profile, dir }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("webclient: profile copy failed (code " .. code .. ")", vim.log.levels.ERROR)
          return
        end
        spawn_chrome(opts, after)
      end)
    end,
  })
end

function M.build()
  local dir = vim.fn.stdpath("config") .. "/webconnect"
  vim.notify("webclient: building webconnect…", vim.log.levels.INFO)
  vim.fn.jobstart({ "go", "build", "-o", "webconnect", "." }, {
    cwd = dir,
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, code)
      vim.schedule(function()
        local lvl = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        vim.notify("webclient: build exit=" .. code, lvl)
      end)
    end,
  })
end

return M
