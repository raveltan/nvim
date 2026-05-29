-- Jump-to-next / jump-to-prev across the inline comments in the current buffer.

local state    = require("phab-inline.state")
local revision = require("phab-inline.revision")

local M = {}

-- Return a sorted list of unique 1-based line numbers in `buf` that have
-- inline comments, or nil if the buffer isn't in a known revision worktree.
local function comment_lines(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return nil end
  local rev = revision.find(name)
  if not rev then return nil end
  local status = state.get_active(rev) or "incomplete"
  local entry = state.get_slot(rev, status)
  if not entry then return nil end
  local rel = revision.rel_path(buf, entry.root)
  if not rel then return nil end
  local comments = entry.by_path[rel]
  if not comments or #comments == 0 then return {} end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local seen, lines = {}, {}
  for _, c in ipairs(comments) do
    local f = c.fields or {}
    local line = math.max(1, tonumber(f.line) or 1)
    if line > line_count then line = line_count end
    if not seen[line] then
      seen[line] = true
      table.insert(lines, line)
    end
  end
  table.sort(lines)
  return lines
end

local function goto_comment(direction)
  local buf = vim.api.nvim_get_current_buf()
  local lines = comment_lines(buf)
  if not lines then
    vim.notify("phab-inline: no inline comments loaded for this buffer", vim.log.levels.INFO)
    return
  end
  if #lines == 0 then
    vim.notify("phab-inline: no inline comments in this buffer", vim.log.levels.INFO)
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if direction == "next" then
    for _, l in ipairs(lines) do
      if l > cur then target = l break end
    end
    if not target then target = lines[1] end -- wrap
  else
    for i = #lines, 1, -1 do
      if lines[i] < cur then target = lines[i] break end
    end
    if not target then target = lines[#lines] end -- wrap
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zv")
end

function M.goto_next() goto_comment("next") end
function M.goto_prev() goto_comment("prev") end

return M
