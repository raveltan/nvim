-- Fetches and displays diff summary and test plan, and supports editing
-- them via acwrite scratch buffers that save back to Phabricator.

local config   = require("phab-inline.config")
local revision = require("phab-inline.revision")

local M = {}

-- cache[rev] = { title = "...", summary = "...", testPlan = "..." }
local cache    = {}
local inflight = {}

-- Fetch summary and test plan for a revision via differential.revision.search.
local function do_fetch(rev, cb)
  if inflight[rev] then return end
  inflight[rev] = true

  local conduit = config.script_path("conduit.sh")
  local id = tonumber(rev:match("^D(%d+)$"))
  if not id then
    inflight[rev] = nil
    vim.schedule(function()
      vim.notify("phab-inline: cannot parse revision id from " .. rev, vim.log.levels.ERROR)
    end)
    return
  end
  local params = vim.json.encode({ constraints = { ids = { id } } })

  vim.system(
    { conduit, "differential.revision.search", params },
    { text = true },
    function(o)
      inflight[rev] = nil
      if o.code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "phab-inline: fetch description failed for " .. rev .. ": " .. (o.stderr or ""),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, o.stdout or "")
      if not ok or type(decoded) ~= "table" then
        vim.schedule(function()
          vim.notify("phab-inline: bad JSON from revision search", vim.log.levels.WARN)
        end)
        return
      end
      local fields = decoded.data
        and decoded.data[1]
        and decoded.data[1].fields
        or {}
      local data = {
        title    = fields.title    or rev,
        summary  = fields.summary  or "",
        testPlan = fields.testPlan or "",
      }
      cache[rev] = data
      vim.schedule(function() cb(data) end)
    end
  )
end

-- Build the display lines and highlight specs for the read-only float.
-- Returns (lines, hls) where hls = list of { row (0-based), hl_group }.
-- Exported so tests can exercise it directly.
function M.build_view(rev, data)
  local lines = {}
  local hls   = {}
  local function add(line, hl)
    table.insert(lines, line)
    if hl then table.insert(hls, { #lines - 1, hl }) end
  end

  local title = data.title or rev
  add(rev .. " - " .. title, "Title")
  add("", nil)

  add("## Summary", "DiagnosticHint")
  add(string.rep("-", 40), "NonText")
  local summary = data.summary or ""
  if summary == "" then
    add("(empty)", "Comment")
  else
    for sline in (summary .. "\n"):gmatch("([^\n]*)\n") do
      add(sline, nil)
    end
  end

  add("", nil)
  add("## Test Plan", "DiagnosticHint")
  add(string.rep("-", 40), "NonText")
  local testPlan = data.testPlan or ""
  if testPlan == "" then
    add("(empty)", "Comment")
  else
    for tline in (testPlan .. "\n"):gmatch("([^\n]*)\n") do
      add(tline, nil)
    end
  end

  return lines, hls
end

-- Open a read-only float showing the summary and test plan.
local function open_float(rev, data)
  local lines, hls = M.build_view(rev, data)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden  = "wipe"
  vim.bo[buf].filetype   = "markdown"
  pcall(vim.api.nvim_buf_set_name, buf, "phab://" .. rev .. "/description")

  local view_ns = vim.api.nvim_create_namespace("phab_inline_description_view")
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, view_ns, h[1], 0, {
      end_row  = h[1] + 1,
      hl_group = h[2],
      hl_eol   = true,
    })
  end

  local ui     = vim.api.nvim_list_uis()[1] or { width = 100, height = 30 }
  local width  = math.min(100, math.max(60, math.floor(ui.width  * 0.7)))
  local height = math.min(#lines + 2, math.max(10, math.floor(ui.height * 0.7)))
  local row    = math.floor((ui.height - height) / 2)
  local col    = math.floor((ui.width  - width)  / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. rev .. " description ",
    title_pos = "center",
    footer    = { { " [s] summary  [t] test plan  [q] close ", "FloatFooter" } },
    footer_pos = "center",
  })
  vim.wo[win].wrap       = true
  vim.wo[win].linebreak  = true
  vim.wo[win].cursorline = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q",     close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })

  -- Hotkeys to jump straight into editing.
  vim.keymap.set("n", "s", function()
    close()
    M.edit_field(rev, "summary")
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "t", function()
    close()
    M.edit_field(rev, "testPlan")
  end, { buffer = buf, silent = true, nowait = true })
end

-- Show summary and test plan in a read-only float.
-- opts.buf:     buffer used to derive the revision (default: current buffer)
-- opts.refresh: if true, bust the cache and refetch before opening
function M.show(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end

  if opts.refresh then cache[rev] = nil end

  if cache[rev] then
    open_float(rev, cache[rev])
    return
  end

  vim.notify("phab-inline: fetching description for " .. rev .. "...", vim.log.levels.INFO)
  do_fetch(rev, function(data)
    open_float(rev, data)
  end)
end

-- Save the contents of an acwrite buffer back to Phabricator.
-- field is "summary" or "testPlan".
function M.save(buf, rev, field)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Strip trailing empty line that Neovim appends.
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  local content = table.concat(lines, "\n")

  local conduit = config.script_path("conduit.sh")
  local params = vim.json.encode({
    objectIdentifier = rev,
    transactions     = { { type = field, value = content } },
  })

  vim.notify("phab-inline: saving " .. field .. " for " .. rev .. "...", vim.log.levels.INFO)
  vim.system(
    { conduit, "differential.revision.edit", params },
    { text = true },
    function(o)
      vim.schedule(function()
        if o.code ~= 0 then
          vim.notify(
            "phab-inline: save failed for " .. rev .. ": " .. (o.stderr or ""),
            vim.log.levels.ERROR
          )
        else
          -- Update cache.
          if cache[rev] then cache[rev][field] = content end
          if vim.api.nvim_buf_is_valid(buf) then
            vim.bo[buf].modified = false
          end
          vim.notify("phab-inline: saved " .. field .. " for " .. rev)
        end
      end)
    end
  )
end

-- Open a field for editing in a scratch buffer with buftype=acwrite.
-- field is "summary" or "testPlan".
-- The buffer name is phab://<rev>/<field>, and :w saves back to Phabricator.
function M.edit_field(rev, field)
  local bname = "phab://" .. rev .. "/" .. field

  -- Reuse an existing buffer if already open.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == bname then
      vim.cmd("buffer " .. b)
      return
    end
  end

  local function populate(data)
    local ebuf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(ebuf, bname)
    vim.bo[ebuf].filetype  = "markdown"
    vim.bo[ebuf].buftype   = "acwrite"
    vim.bo[ebuf].bufhidden = "hide"

    local content = (data and data[field]) or ""
    local lines = vim.split(content, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, lines)
    vim.bo[ebuf].modified = false

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer   = ebuf,
      callback = function() M.save(ebuf, rev, field) end,
    })

    vim.cmd("buffer " .. ebuf)

    local label = field == "testPlan" and "test plan" or field
    vim.notify(
      "phab-inline: editing " .. label .. " for " .. rev .. " -- :w to save to Phabricator",
      vim.log.levels.INFO
    )
  end

  if cache[rev] then
    populate(cache[rev])
  else
    vim.notify("phab-inline: fetching description for " .. rev .. "...", vim.log.levels.INFO)
    do_fetch(rev, function(data)
      populate(data)
    end)
  end
end

-- Public entry points that resolve the revision from the current buffer.
function M.edit_summary(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end
  M.edit_field(rev, "summary")
end

function M.edit_test_plan(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end
  M.edit_field(rev, "testPlan")
end

-- Test hook: wipe all module-local state.
function M._reset()
  cache    = {}
  inflight = {}
end

-- Test hook: get/set cache directly.
function M._get_cache(rev) return cache[rev] end
function M._set_cache(rev, data) cache[rev] = data end

return M
