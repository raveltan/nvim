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

function M.profile_open(path)
  local function open_path(p)
    if not p or p == "" then return end
    if vim.fn.filereadable(p) ~= 1 then
      vim.notify("gaf-xdebug: snapshot not readable: " .. p, vim.log.levels.ERROR)
      return
    end
    if vim.fn.executable("callgrind_annotate") ~= 1 then
      vim.notify("gaf-xdebug: callgrind_annotate not found — opening raw file " ..
        "(brew install valgrind)", vim.log.levels.WARN)
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

  local dir = local_snapshot_dir()
  local local_files = vim.fn.glob(dir .. "/cachegrind.out.*", false, true)
  local tmp_files = vim.fn.glob("/tmp/cachegrind.out.*", false, true)
  local candidates = {}
  for _, f in ipairs(local_files) do table.insert(candidates, f) end
  for _, f in ipairs(tmp_files) do table.insert(candidates, f) end

  if #candidates == 0 then
    vim.notify("No local snapshots. Run :GafXdebugProfileDownload first " ..
      "(searched " .. dir .. ", /tmp).", vim.log.levels.WARN)
    return
  end

  vim.ui.select(candidates, {
    prompt = "Open cachegrind snapshot:",
    format_item = function(p) return vim.fn.fnamemodify(p, ":t") .. "  (" .. p .. ")" end,
  }, function(choice) open_path(choice) end)
end

function M.profile_curl(url)
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
            vim.notify("Snapshot → " .. filename .. "\nName yanked to + register. " ..
              "Pull with :GafXdebugProfileDownload " .. basename, vim.log.levels.INFO)
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
end

return M
