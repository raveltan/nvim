-- Buffer decoration: one extmark per comment carrying the gutter sign and the
-- full body as virtual lines. Extmark signs (not
-- sign_place) so a single clear of the namespace removes everything.

local state  = require("gaf.phab.state")
local lookup = require("gaf.phab.lookup")
local revision = require("gaf.phab.revision")

local M = {}

local ns = vim.api.nvim_create_namespace("gaf_phab_inline")

M.ns = ns

function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

function M.render(buf, rev, status)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if state.is_hidden(rev) then
    M.clear(buf)
    return
  end
  status = status or state.get_active(rev) or "incomplete"
  local slot = state.get_slot(rev, status)
  if not slot then return end
  local rel = revision.rel_path(buf, slot.root)
  if not rel then return end

  M.clear(buf)

  local comments = slot.by_path[rel]
  if not comments or #comments == 0 then return end

  for _, c in ipairs(comments) do
    local row = lookup.line_in(buf, c) - 1
    local author = lookup.author(c)

    local virt_lines = {
      { { "▌ ", "DiagnosticWarn" }, { "phab(" .. author .. "): ", "DiagnosticHint" } },
    }
    for line in (lookup.body(c) .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(virt_lines, { { "▌ ", "DiagnosticWarn" }, { line, "Comment" } })
    end

    pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
      sign_text = ">>",
      sign_hl_group = "DiagnosticWarn",
      virt_lines = virt_lines,
      priority = 10,
    })
  end
end

-- Iterate every loaded buffer belonging to `rev`. With `root` given, the
-- buffer's worktree root must match too (rendering: one rev+root pair owns the
-- data). Pass root = nil to act on any buffer of `rev` (clearing).
local function for_each_buf(rev, root, fn)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        local r, rroot = revision.detect(buf)
        if r == rev and (root == nil or rroot == root) then fn(buf) end
      end
    end
  end
end

function M.render_all(rev, status)
  status = status or state.get_active(rev) or "incomplete"
  local slot = state.get_slot(rev, status)
  if not slot then return end
  for_each_buf(rev, slot.root, function(buf) M.render(buf, rev, status) end)
end

function M.clear_all(rev)
  for_each_buf(rev, nil, function(buf) M.clear(buf) end)
end

return M
