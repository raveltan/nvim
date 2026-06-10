local paths = require("gaf.paths")

local M = {}

local function find_root()
  local start = vim.fn.expand("%:p:h")
  if start == "" then start = vim.fn.getcwd() end
  local dir = start
  while dir ~= "/" and dir ~= "" do
    if vim.fn.executable(dir .. "/bin/gaf-xdebug") == 1 then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

local function run(subcmd, extra_args, opts)
  opts = opts or {}
  local root = find_root()
  if not root then
    vim.notify("gaf-xdebug: bin/gaf-xdebug not found (walked up from buffer)", vim.log.levels.ERROR)
    return
  end
  local args = { root .. "/bin/gaf-xdebug", subcmd }
  for _, a in ipairs(extra_args or {}) do table.insert(args, a) end

  local stdout_lines = {}
  local stderr_lines = {}
  if not opts.quiet then
    vim.notify("gaf-xdebug " .. subcmd .. " (DEV_DNS=" .. paths.dev_dns .. ")", vim.log.levels.INFO)
  end
  vim.fn.jobstart(args, {
    cwd = root,
    env = vim.tbl_extend("force", vim.fn.environ(), { DEV_DNS = paths.dev_dns }),
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) if data then vim.list_extend(stdout_lines, data) end end,
    on_stderr = function(_, data) if data then vim.list_extend(stderr_lines, data) end end,
    on_exit = function(_, code)
      local stdout = table.concat(vim.tbl_filter(function(l) return l ~= "" end, stdout_lines), "\n")
      local stderr = table.concat(vim.tbl_filter(function(l) return l ~= "" end, stderr_lines), "\n")
      if opts.on_exit then
        opts.on_exit(code, stdout_lines, stderr_lines)
        return
      end
      local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
      local merged = stdout
      if stderr ~= "" then merged = (merged ~= "" and (merged .. "\n") or "") .. stderr end
      vim.notify("gaf-xdebug " .. subcmd .. " exit=" .. code ..
        (merged ~= "" and ("\n" .. merged) or ""), level)
    end,
  })
end

local function project_root_or_notify()
  local root = find_root()
  if not root then
    vim.notify("gaf-xdebug: bin/gaf-xdebug not found", vim.log.levels.ERROR)
  end
  return root
end

function M.start() run("start") end
function M.stop() run("stop") end
function M.validate() run("validate") end
function M.logs() run("logs") end

function M.insert_connect()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, line, line, false, { "xdebug_connect_to_client();" })
end

function M.profile_install()
  run("install", { "--modes=profile" })
end

local function parse_snapshot_lines(lines)
  local snapshots = {}
  for _, line in ipairs(lines) do
    local name = line:match("(cachegrind%.out%.[%w%-_.]+)%s*$")
    if name then
      table.insert(snapshots, { name = name, raw = line })
    end
  end
  return snapshots
end

function M.profile_list(callback)
  run("list", {}, {
    quiet = true,
    on_exit = function(code, stdout_lines, stderr_lines)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("gaf-xdebug list exit=" .. code ..
            "\n" .. table.concat(stderr_lines, "\n"), vim.log.levels.ERROR)
          return
        end
        local snapshots = parse_snapshot_lines(stdout_lines)
        if callback then
          callback(snapshots)
          return
        end
        if #snapshots == 0 then
          vim.notify("gaf-xdebug: no remote cachegrind snapshots found", vim.log.levels.WARN)
          return
        end
        local out = { "Remote cachegrind snapshots:" }
        for _, s in ipairs(snapshots) do table.insert(out, "  " .. s.raw) end
        vim.notify(table.concat(out, "\n"), vim.log.levels.INFO)
      end)
    end,
  })
end

local function local_snapshot_dir()
  return vim.g.gaf_xdebug_profile_dir or (vim.fn.stdpath("cache") .. "/gaf-xdebug")
end

-- Defined before M.profile_open_gui: as plain `local function`s further down the
-- file they compiled as (nil) globals inside profile_open_gui's picker branch.
local function snapshot_search_dirs()
  local dirs = { local_snapshot_dir(), "/tmp" }
  local root = find_root()
  if root then table.insert(dirs, root) end
  return dirs
end

local function all_local_snapshots()
  local candidates = {}
  for _, d in ipairs(snapshot_search_dirs()) do
    vim.list_extend(candidates, vim.fn.glob(d .. "/cachegrind.out.*", false, true))
  end
  return candidates
end

function M.profile_download(name, then_fn)
  local root = project_root_or_notify()
  if not root then return end
  local dest = local_snapshot_dir()
  vim.fn.mkdir(dest, "p")

  local function do_download(snapshot)
    run("download", { snapshot, dest .. "/" }, {
      on_exit = function(code, _, stderr_lines)
        vim.schedule(function()
          if code ~= 0 then
            vim.notify("gaf-xdebug download " .. snapshot .. " exit=" .. code ..
              "\n" .. table.concat(stderr_lines, "\n"), vim.log.levels.ERROR)
            return
          end
          local local_path = dest .. "/" .. snapshot
          vim.notify("Downloaded → " .. local_path, vim.log.levels.INFO)
          if then_fn then then_fn(local_path) end
        end)
      end,
    })
  end

  if name and name ~= "" then
    do_download(name)
    return
  end

  M.profile_list(function(snapshots)
    if #snapshots == 0 then
      vim.notify("gaf-xdebug: no remote snapshots to download", vim.log.levels.WARN)
      return
    end
    vim.ui.select(snapshots, {
      prompt = "Download cachegrind snapshot:",
      format_item = function(s) return s.raw end,
    }, function(choice)
      if not choice then return end
      do_download(choice.name)
    end)
  end)
end

function M.profile_open_gui(path)
  local function open_path(p)
    if not p or p == "" then return end
    if vim.fn.filereadable(p) ~= 1 then
      vim.notify("gaf-xdebug: snapshot not readable: " .. p, vim.log.levels.ERROR)
      return
    end
    if vim.fn.executable("qcachegrind") ~= 1 then
      vim.notify("gaf-xdebug: qcachegrind not found (brew install qcachegrind graphviz). " ..
        "Falling back to text view.", vim.log.levels.WARN)
      M.profile_open(p)
      return
    end
    vim.fn.jobstart({ "qcachegrind", p }, { detach = true })
    vim.notify("qcachegrind " .. vim.fn.fnamemodify(p, ":t"), vim.log.levels.INFO)
  end

  if path and path ~= "" then
    open_path(path)
    return
  end

  local candidates = all_local_snapshots()
  if #candidates == 0 then
    vim.notify("No local snapshots (searched " ..
      table.concat(snapshot_search_dirs(), ", ") .. ").", vim.log.levels.WARN)
    return
  end
  vim.ui.select(candidates, {
    prompt = "Open in qcachegrind:",
    format_item = function(p) return vim.fn.fnamemodify(p, ":t") .. "  (" .. p .. ")" end,
  }, function(choice) open_path(choice) end)
end

local function newest_snapshot()
  local candidates = all_local_snapshots()
  if #candidates == 0 then return nil end
  table.sort(candidates, function(a, b)
    return (vim.uv or vim.loop).fs_stat(a).mtime.sec >
           (vim.uv or vim.loop).fs_stat(b).mtime.sec
  end)
  return candidates[1]
end

function M.profile_latest()
  local p = newest_snapshot()
  if not p then
    vim.notify("No local snapshots in cache or /tmp.", vim.log.levels.WARN)
    return
  end
  M.profile_open_gui(p)
end

function M.profile_open(path)
  local function open_path(p)
    if not p or p == "" then return end
    if vim.fn.filereadable(p) ~= 1 then
      vim.notify("gaf-xdebug: snapshot not readable: " .. p, vim.log.levels.ERROR)
      return
    end
    if vim.fn.executable("callgrind_annotate") ~= 1 then
      vim.notify("gaf-xdebug: callgrind_annotate not found — opening raw file " ..
        "(brew install qcachegrind for GUI, or grab callgrind_annotate perl script)",
        vim.log.levels.WARN)
      vim.cmd("edit " .. vim.fn.fnameescape(p))
      return
    end
    local out = vim.fn.systemlist({ "callgrind_annotate", p })
    if vim.v.shell_error ~= 0 then
      vim.notify("callgrind_annotate failed:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
      return
    end
    vim.cmd("vnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
    vim.api.nvim_buf_set_name(buf, "callgrind://" .. vim.fn.fnamemodify(p, ":t"))
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "cachegrind"
  end

  if path and path ~= "" then
    open_path(path)
    return
  end

  local candidates = all_local_snapshots()
  if #candidates == 0 then
    vim.notify("No local snapshots. Run :GafXdebugProfileDownload first " ..
      "(searched " .. table.concat(snapshot_search_dirs(), ", ") .. ").", vim.log.levels.WARN)
    return
  end

  vim.ui.select(candidates, {
    prompt = "Open cachegrind snapshot:",
    format_item = function(p) return vim.fn.fnamemodify(p, ":t") .. "  (" .. p .. ")" end,
  }, function(choice) open_path(choice) end)
end

function M.profile_curl(url, then_fn)
  local function do_curl(u)
    if not u or u == "" then return end
    local extra = vim.g.gaf_xdebug_curl_args or ""
    local cmd = string.format("curl -s -i -H 'cookie: XDEBUG_PROFILE=1' %s %s",
      extra, vim.fn.shellescape(u))
    vim.notify("curl " .. u .. " (XDEBUG_PROFILE=1)", vim.log.levels.INFO)
    vim.fn.jobstart({ "sh", "-c", cmd }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if not data then return end
        local filename
        for _, line in ipairs(data) do
          local m = line:match("[Xx]%-[Xx]debug%-[Pp]rofile%-[Ff]ilename:%s*(.+)")
          if m then filename = vim.fn.trim(m) end
        end
        vim.schedule(function()
          if filename then
            local basename = vim.fn.fnamemodify(filename, ":t")
            vim.fn.setreg("+", basename)
            if then_fn then
              then_fn(basename)
            else
              vim.notify("Snapshot → " .. filename .. "\nName yanked to + register. " ..
                "Pull with :GafXdebugProfileDownload " .. basename, vim.log.levels.INFO)
            end
          else
            vim.notify("No x-xdebug-profile-filename header. Is xdebug profile mode " ..
              "installed on the remote? (:GafXdebugProfileInstall)", vim.log.levels.WARN)
          end
        end)
      end,
      on_stderr = function(_, data)
        if not data then return end
        local err = table.concat(vim.tbl_filter(function(l) return l ~= "" end, data), "\n")
        if err ~= "" then
          vim.schedule(function() vim.notify("curl stderr: " .. err, vim.log.levels.ERROR) end)
        end
      end,
    })
  end

  if url and url ~= "" then
    do_curl(url)
    return
  end
  vim.ui.input({ prompt = "Profile URL: ", default = vim.g.gaf_xdebug_curl_last_url or "" },
    function(input)
      if not input or input == "" then return end
      vim.g.gaf_xdebug_curl_last_url = input
      do_curl(input)
    end)
end

-- Full pipeline: input URL → curl → download → open GUI. One keystroke, no manual steps.
function M.profile_pipeline()
  vim.ui.input({ prompt = "Profile URL: ", default = vim.g.gaf_xdebug_curl_last_url or "" },
    function(input)
      if not input or input == "" then return end
      vim.g.gaf_xdebug_curl_last_url = input
      M.profile_curl(input, function(basename)
        vim.notify("Snapshot ready: " .. basename .. " — downloading...", vim.log.levels.INFO)
        M.profile_download(basename, function(local_path)
          M.profile_open_gui(local_path)
        end)
      end)
    end)
end

----------------------------------------------------------------------
-- Trace mode (memory + time per call). Output: trace.<pid>.xt
-- HTTP: cookie XDEBUG_TRACE=1, devbox writes /tmp/trace.<pid>.xt
-- Tests: XDEBUG_MODE=trace env, file lands at project root
----------------------------------------------------------------------

function M.install_all()
  run("install", { "--modes=debug,profile,trace" })
end

local function all_local_traces()
  local out = {}
  for _, d in ipairs(snapshot_search_dirs()) do
    vim.list_extend(out, vim.fn.glob(d .. "/trace.*.xt", false, true))
    vim.list_extend(out, vim.fn.glob(d .. "/trace.*.xt.gz", false, true))
  end
  return out
end

local function newest_trace()
  local cs = all_local_traces()
  if #cs == 0 then return nil end
  table.sort(cs, function(a, b)
    return (vim.uv or vim.loop).fs_stat(a).mtime.sec >
           (vim.uv or vim.loop).fs_stat(b).mtime.sec
  end)
  return cs[1]
end

-- Parse xdebug human-readable trace (default format=0).
-- Each line: "<time> <memory> <indent>-> Class::method() <file>:<line>"
-- Matched <- pairs give per-call memory delta. Aggregate by function.
local function aggregate_trace(path)
  local lines
  if path:sub(-3) == ".gz" then
    lines = vim.fn.systemlist({ "gunzip", "-c", path })
  else
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    lines = {}
    for l in f:lines() do table.insert(lines, l) end
    f:close()
  end

  local stack = {}        -- per-depth: { fn, mem_in }
  local agg = {}          -- fn → { self=, incl=, calls= }
  local self_charge = {}  -- depth → bytes charged from children (subtract from incl)

  for _, line in ipairs(lines) do
    -- entry: optional leading spaces, time, memory, indent, "->", fn, "(", ...
    local time, mem, indent, fn = line:match(
      "^%s*([%d%.]+)%s+(%d+)(%s+)%-%>%s+([%w_\\:%->%.{}%$]+)%(")
    if time and mem then
      local depth = math.floor(#indent / 2)
      stack[depth] = { fn = fn, mem_in = tonumber(mem) }
      self_charge[depth] = 0
    else
      -- exit: time, memory, indent, "<-"
      local etime, emem, eindent = line:match("^%s*([%d%.]+)%s+(%d+)(%s+)%<%-")
      if etime and emem then
        local depth = math.floor(#eindent / 2)
        local frame = stack[depth]
        if frame then
          local incl = tonumber(emem) - frame.mem_in
          local self_bytes = incl - (self_charge[depth] or 0)
          local a = agg[frame.fn] or { self = 0, incl = 0, calls = 0 }
          a.self = a.self + self_bytes
          a.incl = a.incl + incl
          a.calls = a.calls + 1
          agg[frame.fn] = a
          if depth > 0 then
            self_charge[depth - 1] = (self_charge[depth - 1] or 0) + incl
          end
          stack[depth] = nil
          self_charge[depth] = 0
        end
      end
    end
  end

  local list = {}
  for fn, a in pairs(agg) do
    table.insert(list, { fn = fn, self = a.self, incl = a.incl, calls = a.calls })
  end
  return list
end

local function fmt_bytes(n)
  local abs = math.abs(n)
  if abs >= 1024 * 1024 then return string.format("%8.2f MB", n / 1024 / 1024) end
  if abs >= 1024         then return string.format("%8.2f KB", n / 1024) end
  return string.format("%8d  B", n)
end

function M.trace_aggregate(path, opts)
  opts = opts or {}
  local top_n = opts.top_n or 50

  if not path or path == "" then
    path = newest_trace()
    if not path then
      vim.notify("No local trace files (searched " ..
        table.concat(snapshot_search_dirs(), ", ") .. ").", vim.log.levels.WARN)
      return
    end
  end

  vim.notify("Aggregating " .. vim.fn.fnamemodify(path, ":t") .. "...", vim.log.levels.INFO)
  local list, err = aggregate_trace(path)
  if not list then
    vim.notify("trace aggregate failed: " .. err, vim.log.levels.ERROR)
    return
  end

  local by_self = vim.deepcopy(list)
  table.sort(by_self, function(a, b) return a.self > b.self end)
  local by_incl = vim.deepcopy(list)
  table.sort(by_incl, function(a, b) return a.incl > b.incl end)
  local by_calls = vim.deepcopy(list)
  table.sort(by_calls, function(a, b) return a.calls > b.calls end)

  local out = {
    "Trace memory aggregate: " .. path,
    "Total functions: " .. #list,
    "",
    "=== TOP " .. top_n .. " by SELF bytes (allocated by function alone) ===",
    string.format("%-12s  %-12s  %8s  %s", "SELF", "INCL", "CALLS", "FUNCTION"),
  }
  for i = 1, math.min(top_n, #by_self) do
    local r = by_self[i]
    table.insert(out, string.format("%s  %s  %8d  %s",
      fmt_bytes(r.self), fmt_bytes(r.incl), r.calls, r.fn))
  end
  table.insert(out, "")
  table.insert(out, "=== TOP " .. top_n .. " by INCL bytes (function + callees) ===")
  table.insert(out, string.format("%-12s  %-12s  %8s  %s", "SELF", "INCL", "CALLS", "FUNCTION"))
  for i = 1, math.min(top_n, #by_incl) do
    local r = by_incl[i]
    table.insert(out, string.format("%s  %s  %8d  %s",
      fmt_bytes(r.self), fmt_bytes(r.incl), r.calls, r.fn))
  end
  table.insert(out, "")
  table.insert(out, "=== TOP " .. top_n .. " by CALL COUNT ===")
  table.insert(out, string.format("%-12s  %-12s  %8s  %s", "SELF", "INCL", "CALLS", "FUNCTION"))
  for i = 1, math.min(top_n, #by_calls) do
    local r = by_calls[i]
    table.insert(out, string.format("%s  %s  %8d  %s",
      fmt_bytes(r.self), fmt_bytes(r.incl), r.calls, r.fn))
  end

  vim.cmd("vnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.api.nvim_buf_set_name(buf, "trace-memory://" .. vim.fn.fnamemodify(path, ":t"))
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "xdebug-trace-summary"
end

function M.trace_latest()
  M.trace_aggregate(nil)
end

function M.trace_curl(url, then_fn)
  local function do_curl(u)
    if not u or u == "" then return end
    local extra = vim.g.gaf_xdebug_curl_args or ""
    local cmd_str = string.format("curl -s -i -H 'cookie: XDEBUG_TRACE=1' %s %s",
      extra, vim.fn.shellescape(u))
    vim.notify("curl " .. u .. " (XDEBUG_TRACE=1)", vim.log.levels.INFO)
    vim.fn.jobstart({ "sh", "-c", cmd_str }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if not data then return end
        local filename
        for _, line in ipairs(data) do
          local m = line:match("[Xx]%-[Xx]debug%-[Tt]race%-[Ff]ilename:%s*(.+)")
          if m then filename = vim.fn.trim(m) end
        end
        vim.schedule(function()
          if filename then
            local basename = vim.fn.fnamemodify(filename, ":t")
            vim.fn.setreg("+", basename)
            if then_fn then
              then_fn(basename)
            else
              vim.notify("Trace → " .. filename .. "\nPull with :GafXdebugProfileDownload " ..
                basename, vim.log.levels.INFO)
            end
          else
            vim.notify("No x-xdebug-trace-filename header. Trace mode loaded? " ..
              "(:GafXdebugInstallAll)", vim.log.levels.WARN)
          end
        end)
      end,
      on_stderr = function(_, data)
        if not data then return end
        local err = table.concat(vim.tbl_filter(function(l) return l ~= "" end, data), "\n")
        if err ~= "" then
          vim.schedule(function() vim.notify("curl stderr: " .. err, vim.log.levels.ERROR) end)
        end
      end,
    })
  end

  if url and url ~= "" then
    do_curl(url)
    return
  end
  vim.ui.input({ prompt = "Trace URL: ", default = vim.g.gaf_xdebug_curl_last_url or "" },
    function(input)
      if not input or input == "" then return end
      vim.g.gaf_xdebug_curl_last_url = input
      do_curl(input)
    end)
end

function M.trace_pipeline()
  vim.ui.input({ prompt = "Trace URL: ", default = vim.g.gaf_xdebug_curl_last_url or "" },
    function(input)
      if not input or input == "" then return end
      vim.g.gaf_xdebug_curl_last_url = input
      M.trace_curl(input, function(basename)
        vim.notify("Trace ready: " .. basename .. " — downloading...", vim.log.levels.INFO)
        M.profile_download(basename, function(local_path)
          M.trace_aggregate(local_path)
        end)
      end)
    end)
end

function M.setup()
  local cmd = vim.api.nvim_create_user_command
  cmd("GafXdebugStart",    function() M.start() end,         { desc = "GAF xdebug: start port-forward" })
  cmd("GafXdebugStop",     function() M.stop() end,          { desc = "GAF xdebug: stop port-forward" })
  cmd("GafXdebugValidate", function() M.validate() end,      { desc = "GAF xdebug: validate IDE setup" })
  cmd("GafXdebugLogs",     function() M.logs() end,          { desc = "GAF xdebug: tail logs" })
  cmd("GafXdebugInsert",   function() M.insert_connect() end, { desc = "Insert xdebug_connect_to_client();" })
  cmd("GafXdebugProfileInstall",  function() M.profile_install() end,
    { desc = "GAF xdebug: install profile mode on remote" })
  cmd("GafXdebugProfileList",     function() M.profile_list() end,
    { desc = "GAF xdebug: list remote cachegrind snapshots" })
  cmd("GafXdebugProfileDownload", function(a) M.profile_download(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: download snapshot (picker if no arg)", nargs = "?" })
  cmd("GafXdebugProfileOpen",     function(a) M.profile_open(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: render snapshot via callgrind_annotate", nargs = "?", complete = "file" })
  cmd("GafXdebugProfileCurl",     function(a) M.profile_curl(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: curl URL with XDEBUG_PROFILE=1 cookie", nargs = "?" })
  cmd("GafXdebugProfileGui",      function(a) M.profile_open_gui(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: open snapshot in qcachegrind", nargs = "?", complete = "file" })
  cmd("GafXdebugProfileLatest",   function() M.profile_latest() end,
    { desc = "GAF xdebug: open newest local snapshot in qcachegrind" })
  cmd("GafXdebugProfilePipeline", function() M.profile_pipeline() end,
    { desc = "GAF xdebug: URL input → curl → download → open GUI" })
  cmd("GafXdebugInstallAll", function() M.install_all() end,
    { desc = "GAF xdebug: install debug+profile+trace modes on devbox" })
  cmd("GafXdebugTraceCurl", function(a) M.trace_curl(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: curl URL with XDEBUG_TRACE=1 cookie", nargs = "?" })
  cmd("GafXdebugTraceAggregate", function(a) M.trace_aggregate(a.args ~= "" and a.args or nil) end,
    { desc = "GAF xdebug: aggregate trace by memory (newest if no path)",
      nargs = "?", complete = "file" })
  cmd("GafXdebugTraceLatest", function() M.trace_latest() end,
    { desc = "GAF xdebug: aggregate newest local trace by memory" })
  cmd("GafXdebugTracePipeline", function() M.trace_pipeline() end,
    { desc = "GAF xdebug: URL input → curl → download → aggregate memory" })

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
  end
  -- Time profile (cachegrind → qcachegrind)
  map("<leader>Xp", M.profile_pipeline,    "Xdebug: profile URL TIME (input → curl → GUI)")
  map("<leader>Xo", M.profile_latest,      "Xdebug: open newest snapshot (GUI)")
  map("<leader>XO", function() M.profile_open_gui() end, "Xdebug: pick snapshot → GUI")
  map("<leader>Xc", function() M.profile_open() end,     "Xdebug: pick snapshot → callgrind text")
  map("<leader>Xl", function() M.profile_list() end,     "Xdebug: list remote snapshots")
  map("<leader>Xd", function()
    M.profile_download(nil, function(local_path) M.profile_open_gui(local_path) end)
  end, "Xdebug: download remote → open GUI")
  -- Memory trace (xdebug trace → aggregated by memory)
  map("<leader>Xm", M.trace_pipeline,      "Xdebug: profile URL MEMORY (input → curl → aggregate)")
  map("<leader>XM", M.trace_latest,        "Xdebug: aggregate newest trace by memory")
  map("<leader>Xa", function() M.trace_aggregate() end, "Xdebug: aggregate trace (picker)")
  -- Install + control
  map("<leader>XI", M.install_all,         "Xdebug: install all modes on devbox (debug+profile+trace)")
  map("<leader>Xs", M.start,               "Xdebug: start port-forward (debugger)")
  map("<leader>XS", M.stop,                "Xdebug: stop port-forward")
  map("<leader>Xv", M.validate,            "Xdebug: validate IDE setup")
end

return M
