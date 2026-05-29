-- phab-inline.nvim
-- Shows Phabricator inline review comments inline in nvim buffers.
--
-- Activates for any buffer under a directory whose basename matches D<digits>
-- (e.g. ~/freelancer-dev/fl-gaf-worktree/D225194/...). The revision id is
-- taken from that directory name. Only comments NOT marked done are shown
-- by default; switch via :PhabInlineRefresh done|all (or the Lua API below).
--
-- This file is a thin facade. The real work lives in the sibling modules:
--   config.lua    - defaults + setup() merging + script path resolution
--   state.lua     - cache, in-flight tracking, active-status memory
--   revision.lua  - find the D<id> worktree ancestor of a path
--   fetch.lua     - vim.system() + JSON parsing + PHID -> author resolution
--   render.lua    - namespace, signs, extmarks, render across buffers
--   nav.lua       - jump-to-next / jump-to-prev inside a buffer
--   commands.lua  - :PhabInline* commands, optional keymaps, autocmd

local config   = require("phab-inline.config")
local state    = require("phab-inline.state")
local revision = require("phab-inline.revision")
local fetch    = require("phab-inline.fetch")
local render   = require("phab-inline.render")
local nav      = require("phab-inline.nav")
local comments    = require("phab-inline.comments")
local description = require("phab-inline.description")
local commands    = require("phab-inline.commands")

local M = {}

function M.refresh(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local status = state.norm_status(opts.status)
  local rev, root = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end
  -- Drop the cached slot for this status so we refetch fresh.
  state.drop_slot(rev, status)
  state.set_active(rev, status)
  -- Clear decorations in any buffer of this rev before rendering the new set.
  render.clear_all(rev)
  fetch.fetch(rev, root, status, function() render.render_all(rev, status) end)
end

function M.clear_buf(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  render.clear(buf)
end

M.goto_next = nav.goto_next
M.goto_prev = nav.goto_prev

-- Open every file in the current revision that has inline comments.
-- Each file is opened in its own buffer (via :badd) and the first one is
-- shown in the current window.
function M.open_all(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local status = state.norm_status(opts.status)
  local rev, root = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end
  state.set_active(rev, status)

  local function do_open()
    local entry = state.get_slot(rev, status)
    if not entry then return end
    local paths = {}
    for p, comments in pairs(entry.by_path) do
      if comments and #comments > 0 then
        table.insert(paths, p)
      end
    end
    if #paths == 0 then
      vim.notify("phab-inline: no files with inline comments", vim.log.levels.INFO)
      return
    end
    table.sort(paths)

    local root_abs = vim.fn.fnamemodify(entry.root, ":p"):gsub("/$", "")
    local first
    for _, p in ipairs(paths) do
      local full = root_abs .. "/" .. p
      if vim.fn.filereadable(full) == 1 then
        vim.cmd("badd " .. vim.fn.fnameescape(full))
        if not first then first = full end
      else
        vim.notify("phab-inline: missing file " .. p, vim.log.levels.WARN)
      end
    end
    if first then
      vim.cmd("edit " .. vim.fn.fnameescape(first))
    end
    vim.notify(
      "phab-inline: opened " .. #paths .. " file(s) with " .. status .. " inline comments",
      vim.log.levels.INFO
    )
  end

  if state.get_slot(rev, status) then
    do_open()
  else
    fetch.fetch(rev, root, status, function()
      render.render_all(rev, status)
      do_open()
    end)
  end
end

function M.is_hidden(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev = revision.find(revision.context_path(buf))
  if not rev then return false end
  return state.is_hidden(rev)
end

function M.toggle(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev, root = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end
  if state.is_hidden(rev) then
    state.set_hidden(rev, false)
    local status = state.get_active(rev) or "incomplete"
    if state.get_slot(rev, status) then
      render.render_all(rev, status)
    else
      fetch.fetch(rev, root, status, function() render.render_all(rev, status) end)
    end
  else
    state.set_hidden(rev, true)
    render.clear_all(rev)
  end
end

function M.on_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return end
  local rev, root = revision.find(name)
  if not rev then return end
  local status = state.get_active(rev) or "incomplete"
  state.set_active(rev, status)
  if state.get_slot(rev, status) then
    render.render(buf, rev, status)
  else
    fetch.fetch(rev, root, status, function() render.render_all(rev, status) end)
  end
end

function M.show_comments(opts) comments.show(opts) end
function M.show_description(opts) description.show(opts) end
function M.edit_summary(opts) description.edit_summary(opts) end
function M.edit_test_plan(opts) description.edit_test_plan(opts) end

function M.setup(user_config)
  config.set(user_config)
  commands.install(M)
end

return M
