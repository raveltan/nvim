-- External calls: invokes the bundled scripts via vim.system, parses the JSON
-- output, and resolves author PHIDs to display names. This is the only module
-- that shells out.

local config = require("gaf.phab.config")
local state  = require("gaf.phab.state")
local util   = require("gaf.phab.util")

local M = {}

-- Parse the script output. The script prints a JSON array of inline
-- transactions and already filters by status; re-filter on isDone defensively.
local function parse(stdout, status)
  local ok, decoded = pcall(vim.json.decode, stdout)
  if not ok or type(decoded) ~= "table" then return {} end
  local out = {}
  for _, c in ipairs(decoded) do
    local f = c.fields or {}
    if f.path and f.line then
      local is_done = f.isDone == true
      local keep
      if status == "done" then
        keep = is_done
      elseif status == "all" then
        keep = true
      else -- incomplete
        keep = not is_done
      end
      if keep then table.insert(out, c) end
    end
  end
  return out
end

-- Resolve PHID -> display name for the authors in `items`, via conduit's
-- phid.query. Best-effort: on failure the PHID is left as the author.
function M.resolve_authors(items, cb)
  local phids, seen = {}, {}
  for _, c in ipairs(items) do
    local p = c.authorPHID
    if p and not seen[p] then
      seen[p] = true
      table.insert(phids, p)
    end
  end
  if #phids == 0 then
    cb({})
    return
  end

  local conduit = config.script_path("conduit.sh")
  local params = vim.json.encode({ phids = phids })

  vim.system({ conduit, "phid.query", params }, { text = true }, function(o)
    local map = {}
    if o.code == 0 and o.stdout and o.stdout ~= "" then
      local ok, decoded = pcall(vim.json.decode, o.stdout)
      if ok and type(decoded) == "table" then
        -- conduit.sh prints the unwrapped result: an object keyed by PHID.
        for phid, info in pairs(decoded) do
          if type(info) == "table" then
            map[phid] = info.name or info.fullName or phid
          end
        end
      end
    end
    cb(map)
  end)
end

function M.fetch(rev, root, status, on_done)
  status = state.norm_status(status)
  local key = rev .. "\0" .. status
  if not state.inflight_set(key) then return end

  local progress = util.progress(rev, "inline comments (" .. status .. ")")

  vim.system(
    { config.get().script, rev, "--status", status, "--raw" },
    { text = true },
    function(o)
      if o.code ~= 0 then
        state.inflight_clear(key)
        progress.fail("fetch failed")
        vim.schedule(function()
          util.notify(
            "fetch failed for " .. rev .. " (" .. status .. "): " .. (o.stderr or ""),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local items = parse(o.stdout or "", status)
      M.resolve_authors(items, function(authors)
        for _, c in ipairs(items) do
          c._author = authors[c.authorPHID] or c.authorPHID or "phab"
        end
        local by_path = {}
        for _, c in ipairs(items) do
          local p = c.fields.path
          by_path[p] = by_path[p] or {}
          table.insert(by_path[p], c)
        end
        state.set_slot(rev, status, { root = root, by_path = by_path })
        state.inflight_clear(key)
        progress.finish(#items .. " comment(s)")
        vim.schedule(function()
          if on_done then on_done() end
        end)
      end)
    end
  )
end

return M
