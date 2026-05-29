-- Per-revision cache, in-flight tracking, and active-status memory.
--
-- cache[rev][status] = { root = "<abs path>", by_path = { [relpath] = { entry, ... } } }
-- status is one of "incomplete", "done", "all".

local M = {}

local cache = {}
-- inflight[rev .. "\0" .. status] = true while a fetch is running
local inflight = {}
-- active_status[rev] = which status set is currently being rendered for rev.
-- Defaults to "incomplete" the first time we touch a rev.
local active_status = {}
-- hidden[rev] = true when the user has toggled visibility off.
-- Cache is kept intact; rendering is suppressed until toggled back.
local hidden = {}

local VALID_STATUS = { incomplete = true, done = true, all = true }

function M.norm_status(s)
  if s == nil or s == "" then return "incomplete" end
  if not VALID_STATUS[s] then
    vim.notify(
      "phab-inline: invalid status '" .. tostring(s) .. "', using 'incomplete'",
      vim.log.levels.WARN
    )
    return "incomplete"
  end
  return s
end

function M.get_slot(rev, status)
  local r = cache[rev]
  if not r then return nil end
  return r[status]
end

function M.set_slot(rev, status, slot)
  cache[rev] = cache[rev] or {}
  cache[rev][status] = slot
end

function M.drop_slot(rev, status)
  if cache[rev] then cache[rev][status] = nil end
end

function M.set_active(rev, status) active_status[rev] = status end
function M.get_active(rev) return active_status[rev] end

function M.set_hidden(rev, val) hidden[rev] = val end
function M.is_hidden(rev) return hidden[rev] == true end

-- Returns true if we successfully claimed the slot (caller should proceed),
-- false if a fetch for this key was already in flight.
function M.inflight_set(key)
  if inflight[key] then return false end
  inflight[key] = true
  return true
end

function M.inflight_clear(key) inflight[key] = nil end

-- Test hook: wipe all module-local state. Not part of the public API.
function M._reset()
  cache = {}
  inflight = {}
  active_status = {}
  hidden = {}
end

return M
