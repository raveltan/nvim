-- Diff summary and test plan: a read-only markdown float, plus acwrite
-- scratch buffers that write the field back to Phabricator on :w.

local config   = require("gaf.phab.config")
local revision = require("gaf.phab.revision")
local float    = require("gaf.phab.float")
local util     = require("gaf.phab.util")

local M = {}

-- cache[rev] = { title = "...", summary = "...", testPlan = "..." }
local cache    = {}
local inflight = {}

local function do_fetch(rev, cb)
  if inflight[rev] then return end

  local id = tonumber(rev:match("^D(%d+)$"))
  if not id then
    util.notify("cannot parse revision id from " .. rev, vim.log.levels.ERROR)
    return
  end
  inflight[rev] = true

  local conduit  = config.script_path("conduit.sh")
  local params   = vim.json.encode({ constraints = { ids = { id } } })
  local progress = util.progress(rev, "description")

  vim.system({ conduit, "differential.revision.search", params }, { text = true }, function(o)
    inflight[rev] = nil
    if o.code ~= 0 then
      progress.fail("fetch failed")
      vim.schedule(function()
        util.notify("fetch description failed for " .. rev .. ": " .. (o.stderr or ""), vim.log.levels.WARN)
      end)
      return
    end
    local ok, decoded = pcall(vim.json.decode, o.stdout or "")
    if not ok or type(decoded) ~= "table" then
      progress.fail("bad JSON")
      vim.schedule(function() util.notify("bad JSON from revision search", vim.log.levels.WARN) end)
      return
    end
    local fields = decoded.data and decoded.data[1] and decoded.data[1].fields or {}
    local data = {
      title    = fields.title    or rev,
      summary  = fields.summary  or "",
      testPlan = fields.testPlan or "",
    }
    cache[rev] = data
    progress.finish(data.title)
    vim.schedule(function() cb(data) end)
  end)
end

local function section(lines, heading, body)
  table.insert(lines, "## " .. heading)
  table.insert(lines, "")
  if body == "" then
    table.insert(lines, "_empty_")
  else
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
end

-- Markdown body of the float. Exported so it can be exercised on its own.
function M.build_view(rev, data)
  local lines = { "# " .. rev .. " — " .. (data.title or rev), "" }
  section(lines, "Summary", data.summary or "")
  section(lines, "Test Plan", data.testPlan or "")
  return lines
end

local function open(rev, data)
  local win
  win = float.open({
    title  = rev .. " description",
    lines  = M.build_view(rev, data),
    footer = "[s] summary  [t] test plan  [q] close",
    keys = {
      summary = { "s", function()
        win:close()
        M.edit_field(rev, "summary")
      end, desc = "Edit summary" },
      test_plan = { "t", function()
        win:close()
        M.edit_field(rev, "testPlan")
      end, desc = "Edit test plan" },
    },
  })
  return win
end

-- opts.buf:     buffer the revision is derived from (default: current)
-- opts.rev:     explicit revision id, skipping detection
-- opts.refresh: bust the cache and refetch first
function M.show(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev)
    if opts.refresh then cache[rev] = nil end

    if cache[rev] then
      open(rev, cache[rev])
      return
    end

    do_fetch(rev, function(data) open(rev, data) end)
  end)
end

-- Write an acwrite buffer back to Phabricator. field is "summary"|"testPlan".
-- The whole field is overwritten; there is no merge with concurrent edits.
function M.save(buf, rev, field)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  local content = table.concat(lines, "\n")

  local conduit = config.script_path("conduit.sh")
  local params = vim.json.encode({
    objectIdentifier = rev,
    transactions     = { { type = field, value = content } },
  })

  local progress = util.progress(rev, "saving " .. field)
  vim.system({ conduit, "differential.revision.edit", params }, { text = true }, function(o)
    if o.code ~= 0 then
      progress.fail("save failed")
      vim.schedule(function()
        util.notify("save failed for " .. rev .. ": " .. (o.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end
    progress.finish("saved " .. field)
    vim.schedule(function()
      if cache[rev] then cache[rev][field] = content end
      if vim.api.nvim_buf_is_valid(buf) then vim.bo[buf].modified = false end
      util.notify("saved " .. field .. " for " .. rev)
    end)
  end)
end

-- Open a field in a scratch buffer named phab://<rev>/<field>. buftype=acwrite
-- so :w routes through BufWriteCmd instead of touching the filesystem.
function M.edit_field(rev, field)
  local bname = "phab://" .. rev .. "/" .. field

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == bname then
      vim.cmd("buffer " .. b)
      return
    end
  end

  local function populate(data)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, bname)
    vim.bo[buf].filetype  = "markdown"
    vim.bo[buf].buftype   = "acwrite"
    vim.bo[buf].bufhidden = "hide"

    local content = (data and data[field]) or ""
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n", { plain = true }))
    vim.bo[buf].modified = false

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer   = buf,
      callback = function() M.save(buf, rev, field) end,
    })

    vim.cmd("buffer " .. buf)
    util.notify(
      "editing " .. (field == "testPlan" and "test plan" or field) .. " for " .. rev .. " — :w to save"
    )
  end

  if cache[rev] then
    populate(cache[rev])
  else
    do_fetch(rev, populate)
  end
end

-- Entry points that resolve the revision from the current buffer.
local function edit(opts, field)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev)
    M.edit_field(rev, field)
  end)
end

function M.edit_summary(opts) edit(opts, "summary") end
function M.edit_test_plan(opts) edit(opts, "testPlan") end

function M._reset()
  cache    = {}
  inflight = {}
end

function M._get_cache(rev) return cache[rev] end
function M._set_cache(rev, data) cache[rev] = data end

return M
