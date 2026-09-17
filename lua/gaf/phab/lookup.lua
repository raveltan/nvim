-- Resolving a buffer to the cached comments that belong to it. Shared by
-- render (decorations), nav (]p / [p) and pick (the pickers), which all need
-- the same rev -> active status -> slot -> relative path walk.

local state    = require("gaf.phab.state")
local revision = require("gaf.phab.revision")

local M = {}

-- Body of a comment transaction, "" when it carries none.
function M.body(c)
  if c.comments and c.comments[1] and c.comments[1].content then
    return c.comments[1].content.raw or ""
  end
  return ""
end

function M.author(c) return c._author or c.authorPHID or "phab" end

-- First non-empty line of the body, for one-line previews.
function M.headline(c)
  for line in (M.body(c) .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("%S") then return line end
  end
  return ""
end

-- The comment's line, clamped into `buf` (diff line numbers drift against
-- local edits).
function M.line_in(buf, c)
  local line = math.max(1, tonumber((c.fields or {}).line) or 1)
  local count = vim.api.nvim_buf_line_count(buf)
  return math.min(line, count)
end

-- The active status for the rev owning `buf`, its cached slot, and the
-- comments recorded against this buffer's path. Returns nil when the buffer is
-- outside a D<id> worktree or nothing is cached for it yet.
---@return string? rev, table? slot, table? comments
function M.for_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return nil end
  local rev = revision.detect(buf)
  if not rev then return nil end
  local status = state.get_active(rev) or "incomplete"
  local slot = state.get_slot(rev, status)
  if not slot then return rev end
  local rel = revision.rel_path(buf, slot.root)
  if not rel then return rev, slot end
  return rev, slot, slot.by_path[rel]
end

return M
