-- Buffer decoration: namespace, signs, extmarks. Owns the rendering of
-- cached comment data into actual visible UI.

local state    = require("phab-inline.state")
local revision = require("phab-inline.revision")

local M = {}

local ns = vim.api.nvim_create_namespace("phab_inline")
local sign_group = "phab_inline"

-- Defined once at module load. sign_define is idempotent, but doing it here
-- avoids the per-render pcall in the old implementation.
pcall(vim.fn.sign_define, "PhabInlineComment", {
  text = ">>",
  texthl = "DiagnosticWarn",
  numhl = "",
})

M.ns = ns

function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    pcall(vim.fn.sign_unplace, sign_group, { buffer = buf })
  end
end

function M.render(buf, rev, status)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if state.is_hidden(rev) then
    M.clear(buf)
    return
  end
  status = status or state.get_active(rev) or "incomplete"
  local entry = state.get_slot(rev, status)
  if not entry then return end
  local rel = revision.rel_path(buf, entry.root)
  if not rel then return end
  local comments = entry.by_path[rel]
  if not comments or #comments == 0 then
    M.clear(buf)
    return
  end

  M.clear(buf)

  local line_count = vim.api.nvim_buf_line_count(buf)

  for _, c in ipairs(comments) do
    local f = c.fields or {}
    local line = math.max(1, tonumber(f.line) or 1)
    -- Clamp to buffer bounds; line numbers may drift relative to local edits.
    if line > line_count then line = line_count end
    local row = line - 1

    local body = ""
    if c.comments and c.comments[1] and c.comments[1].content then
      body = c.comments[1].content.raw or ""
    end
    local author = c._author or (c.authorPHID or "phab")

    -- Virtual lines below the commented line, full body.
    local virt_lines = {
      {
        { "▌ ", "DiagnosticWarn" },
        { "phab(" .. author .. "): ", "DiagnosticHint" },
      },
    }
    for bline in (body .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(virt_lines, {
        { "▌ ", "DiagnosticWarn" },
        { bline, "Comment" },
      })
    end
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })

    -- Sign in gutter
    pcall(vim.fn.sign_place, 0, sign_group, "PhabInlineComment", buf, {
      lnum = line,
      priority = 10,
    })
  end
end

-- Iterate every loaded buffer that belongs to `rev`. If `root` is given,
-- additionally require the buffer's worktree root to match (used for
-- rendering, where a single rev+root pair owns the data). Pass `root = nil`
-- to act on any buffer of `rev` regardless of root (used for clearing).
local function for_each_buf(rev, root, fn)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        local r, rroot = revision.find(name)
        if r == rev and (root == nil or rroot == root) then fn(buf) end
      end
    end
  end
end

function M.render_all(rev, status)
  status = status or state.get_active(rev) or "incomplete"
  local entry = state.get_slot(rev, status)
  if not entry then return end
  for_each_buf(rev, entry.root, function(buf) M.render(buf, rev, status) end)
end

-- Clear decorations in any loaded buffer belonging to `rev`, regardless of
-- worktree root. Used before re-rendering after a status switch.
function M.clear_all(rev)
  for_each_buf(rev, nil, function(buf) M.clear(buf) end)
end

return M
