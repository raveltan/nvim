-- Snacks pickers over the cached inline comments: one over the files that
-- carry comments, one over the individual comments. Both preview the real
-- file at the commented line, and both accept a multi-selection (<Tab>) to
-- open several at once, which is what the old "open every file" command did
-- unconditionally.

local state    = require("gaf.phab.state")
local revision = require("gaf.phab.revision")
local fetch    = require("gaf.phab.fetch")
local render   = require("gaf.phab.render")
local lookup   = require("gaf.phab.lookup")
local util     = require("gaf.phab.util")

local M = {}

-- Resolve the revision for `buf`, make sure `status` is cached and rendered,
-- then hand the slot to cb. Sets the status active either way, so ]p / [p and
-- BufEnter follow whatever was last asked for.
local function with_slot(opts, cb)
  local status = state.norm_status(opts.status)
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev, root)
    state.set_active(rev, status)

    local function run()
      local slot = state.get_slot(rev, status)
      if slot then cb(rev, status, slot) end
    end

    if state.get_slot(rev, status) then
      run()
    else
      fetch.fetch(rev, root, status, function()
        render.render_all(rev, status)
        run()
      end)
    end
  end)
end

-- Absolute path of a comment path inside the worktree, or nil if it is gone
-- (a file the revision touched but the local checkout does not have).
local function abs_path(slot, rel)
  local root = vim.fn.fnamemodify(slot.root, ":p"):gsub("/$", "")
  local full = root .. "/" .. rel
  if vim.fn.filereadable(full) ~= 1 then return nil end
  return full
end

local function sorted_paths(slot)
  local paths = {}
  for rel, comments in pairs(slot.by_path) do
    if comments and #comments > 0 then table.insert(paths, rel) end
  end
  table.sort(paths)
  return paths
end

-- Picker over the files that have comments of the active status.
function M.files(opts)
  with_slot(opts or {}, function(rev, status, slot)
    local items, missing = {}, 0
    for _, rel in ipairs(sorted_paths(slot)) do
      local full = abs_path(slot, rel)
      if full then
        local n = #slot.by_path[rel]
        items[#items + 1] = {
          text = rel,
          file = full,
          -- Land on the first comment rather than line 1.
          pos = { math.max(1, tonumber((slot.by_path[rel][1].fields or {}).line) or 1), 0 },
          comments = n,
        }
      else
        missing = missing + 1
      end
    end
    if #items == 0 then
      util.notify("no files with " .. status .. " inline comments")
      return
    end
    if missing > 0 then
      util.notify(missing .. " commented file(s) missing from the checkout", vim.log.levels.WARN)
    end
    Snacks.picker.pick({
      title = rev .. " files (" .. status .. ")",
      items = items,
      format = "file",
      preview = "file",
      layout = { preset = "telescope" },
    })
  end)
end

-- Picker over every individual comment of the active status.
function M.comments(opts)
  with_slot(opts or {}, function(rev, status, slot)
    local items = {}
    for _, rel in ipairs(sorted_paths(slot)) do
      local full = abs_path(slot, rel)
      if full then
        for _, c in ipairs(slot.by_path[rel]) do
          local line = math.max(1, tonumber((c.fields or {}).line) or 1)
          items[#items + 1] = {
            text = ("%s:%d %s: %s"):format(rel, line, lookup.author(c), lookup.headline(c)),
            file = full,
            pos = { line, 0 },
            line = lookup.headline(c),
          }
        end
      end
    end
    if #items == 0 then
      util.notify("no " .. status .. " inline comments")
      return
    end
    Snacks.picker.pick({
      title = rev .. " comments (" .. status .. ")",
      items = items,
      format = "file",
      preview = "file",
      layout = { preset = "ivy" },
    })
  end)
end

return M
