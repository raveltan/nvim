-- Phabricator inline review comments, shown in the buffer they were left on.
--
-- The revision is resolved per worktree: an explicit id the user set, a
-- D<digits> ancestor directory, an `arcpatch-D<id>` branch, the
-- `Differential Revision:` trailer of a recent commit, or -- when none of
-- those answer -- by asking once per worktree. Comment paths resolve against
-- the worktree root (the D<id> directory when that is the layout).
--
-- Only comments not marked done are shown by default; switch with
-- :PhabRefresh done|all.
--
-- GAF-only, started from lua/gaf/init.lua. The modules:
--   config.lua      defaults, setup() merge, bundled script paths
--   state.lua       per-revision cache, in-flight tracking, active status
--   revision.lua    work out which revision a buffer belongs to (dir name,
--                   branch, commit trailer, or by asking) + path helpers
--   fetch.lua       vim.system + JSON parsing + PHID -> author resolution
--   lookup.lua      buffer -> cached comments, and comment field accessors
--   render.lua      extmark signs, end-of-line preview, virtual-line bodies
--   nav.lua         ]p / [p inside a buffer
--   pick.lua        Snacks pickers over commented files / comments
--   float.lua       shared read-only markdown float (Snacks.win)
--   comments.lua    general (non-inline) revision comments
--   description.lua diff summary + test plan, incl. editing them back
--   commands.lua    :Phab* commands, keymaps, toggle registration, autocmd
--   util.lua        notifications + fidget progress

local config   = require("gaf.phab.config")
local state    = require("gaf.phab.state")
local revision = require("gaf.phab.revision")
local fetch    = require("gaf.phab.fetch")
local render   = require("gaf.phab.render")
local nav      = require("gaf.phab.nav")
local pick     = require("gaf.phab.pick")
local util     = require("gaf.phab.util")

local M = {}

-- Drop the cached slot for `status` and refetch it. opts.rev overrides the
-- detected revision (and is remembered for this worktree).
function M.refresh(opts)
  opts = opts or {}
  local status = state.norm_status(opts.status)
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev, root)
    state.drop_slot(rev, status)
    state.set_active(rev, status)
    -- Decorations of the previous status set would otherwise survive the switch.
    render.clear_all(rev)
    fetch.fetch(rev, root, status, function() render.render_all(rev, status) end)
  end)
end

-- Set (or ask for) the revision this worktree is reviewing, then load it.
-- opts.rev skips the prompt.
function M.set_revision(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local root = revision.git_root(revision.context_path(buf))
  local previous = root and select(1, revision.detect(buf)) or nil
  if root then revision.forget(root) end

  revision.resolve({ buf = buf, rev = opts.rev, prompt = true }, function(rev)
    if previous and previous ~= rev then
      -- Decorations of the revision we just left would otherwise stay put.
      render.clear_all(previous)
    end
    util.notify("reviewing " .. rev)
    M.refresh({ buf = buf, rev = rev, status = opts.status })
  end)
end

function M.clear_buf(buf)
  render.clear(buf or vim.api.nvim_get_current_buf())
end

M.goto_next = nav.goto_next
M.goto_prev = nav.goto_prev

-- Pick among the files that carry comments (replaces the old open-everything).
M.open_all = pick.files
-- Pick among the individual comments.
M.list = pick.comments

function M.is_hidden(opts)
  opts = opts or {}
  local rev = revision.detect(opts.buf or vim.api.nvim_get_current_buf())
  if not rev then return false end
  return state.is_hidden(rev)
end

function M.toggle(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, prompt = true }, function(rev, root)
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
  end)
end

-- BufReadPost / BufEnter hook: render from cache, or fetch once per revision
-- per status per session. When nothing identifies the revision, ask — but only
-- the first time a worktree is entered, and never for a buffer with no file.
function M.on_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.api.nvim_buf_get_name(buf) == "" then return end
  if vim.bo[buf].buftype ~= "" then return end

  revision.resolve({ buf = buf, prompt_once = config.get().prompt_on_open }, function(rev, root)
    local status = state.get_active(rev) or "incomplete"
    state.set_active(rev, status)
    if state.get_slot(rev, status) then
      render.render(buf, rev, status)
    else
      fetch.fetch(rev, root, status, function() render.render_all(rev, status) end)
    end
  end)
end

-- Open the revision in the browser.
function M.open_browser(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev)
    local base = config.get().url:gsub("/$", "")
    vim.ui.open(base .. "/" .. rev)
  end)
end

function M.show_comments(opts) require("gaf.phab.comments").show(opts) end
function M.show_description(opts) require("gaf.phab.description").show(opts) end
function M.edit_summary(opts) require("gaf.phab.description").edit_summary(opts) end
function M.edit_test_plan(opts) require("gaf.phab.description").edit_test_plan(opts) end

function M.setup(user_config)
  config.set(user_config)
  require("gaf.phab.commands").install(M)
end

return M
