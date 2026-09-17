-- Non-inline (general) revision comments, shown in a markdown float. Uses the
-- bundled phab-comments.sh and shares PHID resolution with fetch.lua.

local config   = require("gaf.phab.config")
local revision = require("gaf.phab.revision")
local fetch    = require("gaf.phab.fetch")
local float    = require("gaf.phab.float")
local lookup   = require("gaf.phab.lookup")
local util     = require("gaf.phab.util")

local M = {}

-- cache[rev]    = { items = { transaction, ... } }  (oldest-first, resolved)
-- inflight[rev] = true while a fetch is running
local cache    = {}
local inflight = {}

local function do_fetch(rev, cb)
  if inflight[rev] then return end
  inflight[rev] = true

  local progress = util.progress(rev, "revision comments")

  vim.system(
    { config.get().comments_script, rev, "--raw" },
    { text = true },
    function(o)
      if o.code ~= 0 then
        inflight[rev] = nil
        progress.fail("fetch failed")
        vim.schedule(function()
          util.notify("fetch comments failed for " .. rev .. ": " .. (o.stderr or ""), vim.log.levels.WARN)
        end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, o.stdout or "")
      local items = (ok and type(decoded) == "table") and decoded or {}
      fetch.resolve_authors(items, function(authors)
        for _, c in ipairs(items) do
          c._author = authors[c.authorPHID] or c.authorPHID or "phab"
        end
        cache[rev] = { items = items }
        inflight[rev] = nil
        progress.finish(#items .. " comment(s)")
        vim.schedule(function() if cb then cb(items) end end)
      end)
    end
  )
end

-- Markdown body of the float. Exported so it can be exercised on its own.
function M.build_view(rev, items)
  local lines = { "# " .. rev .. " — " .. #items .. " comment(s)", "" }

  if #items == 0 then
    table.insert(lines, "_no general comments_")
    return lines
  end

  for i, c in ipairs(items) do
    local date = c.dateCreated and os.date("!%Y-%m-%d %H:%M UTC", tonumber(c.dateCreated)) or ""
    table.insert(lines, ("## %s — %s"):format(lookup.author(c), date))
    table.insert(lines, "")
    for line in (lookup.body(c) .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
    if i < #items then table.insert(lines, "") end
  end

  return lines
end

local function open(rev, items)
  float.open({ title = rev .. " comments", lines = M.build_view(rev, items) })
end

-- opts.buf:     buffer the revision is derived from (default: current)
-- opts.rev:     explicit revision id, skipping detection
-- opts.refresh: bust the cache and refetch first
function M.show(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev)
    if opts.refresh then cache[rev] = nil end

    if cache[rev] then
      open(rev, cache[rev].items)
      return
    end

    do_fetch(rev, function(items) open(rev, items) end)
  end)
end

function M._reset()
  cache    = {}
  inflight = {}
end

return M
