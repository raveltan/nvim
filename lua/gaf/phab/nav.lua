-- Jump to the next / previous inline comment in the current buffer.

local lookup = require("gaf.phab.lookup")
local util   = require("gaf.phab.util")

local M = {}

-- Sorted, de-duplicated 1-based lines of the current buffer that carry a
-- comment, or nil when nothing is loaded for the buffer.
local function comment_lines(buf)
  local _, _, comments = lookup.for_buf(buf)
  if not comments then return nil end
  local seen, lines = {}, {}
  for _, c in ipairs(comments) do
    local line = lookup.line_in(buf, c)
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
    util.notify("no inline comments loaded for this buffer")
    return
  end
  if #lines == 0 then
    util.notify("no inline comments in this buffer")
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if direction == "next" then
    for _, l in ipairs(lines) do
      if l > cur then target = l break end
    end
    target = target or lines[1] -- wrap
  else
    for i = #lines, 1, -1 do
      if lines[i] < cur then target = lines[i] break end
    end
    target = target or lines[#lines] -- wrap
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zv")
end

function M.goto_next() goto_comment("next") end
function M.goto_prev() goto_comment("prev") end

return M
