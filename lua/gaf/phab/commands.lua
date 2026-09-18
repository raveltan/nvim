-- User-facing wiring: :Phab* commands, keymaps, the visibility toggle in the
-- Snacks.toggle registry, and the BufReadPost / BufEnter autocmd.

local config   = require("gaf.phab.config")
local revision = require("gaf.phab.revision")

local M = {}

local STATUSES = { incomplete = true, done = true, all = true }

local function status_complete() return { "incomplete", "done", "all" } end

-- Commands take a status, a revision id, or both, in either order:
--   :PhabRefresh done          :PhabFiles D229985 all      :PhabList 229985
local function parse(args)
  local out = {}
  for word in (args or ""):gmatch("%S+") do
    if STATUSES[word] then
      out.status = word
    else
      out.rev = revision.normalize(word) or out.rev
    end
  end
  return out
end

-- `api` is the gaf.phab module table.
function M.install(api)
  local function cmd(name, fn, opts)
    vim.api.nvim_create_user_command(name, fn, opts)
  end

  cmd("PhabRefresh", function(o) api.refresh(parse(o.args)) end, {
    desc = "Refetch Phabricator inline comments ([status] [Dxxx])",
    nargs = "*",
    complete = status_complete,
  })
  cmd("PhabRevision", function(o) api.set_revision(parse(o.args)) end, {
    desc = "Set the revision this worktree reviews (asks when given no id)",
    nargs = "*",
  })
  cmd("PhabOpen", function(o) api.open_browser(parse(o.args)) end, {
    desc = "Open the revision in the browser",
    nargs = "*",
  })
  cmd("PhabClear", function() api.clear_buf() end, {
    desc = "Clear Phabricator inline comment decorations in this buffer",
  })
  cmd("PhabFiles", function(o) api.open_all(parse(o.args)) end, {
    desc = "Pick among the files with Phabricator inline comments",
    nargs = "*",
    complete = status_complete,
  })
  cmd("PhabList", function(o) api.list(parse(o.args)) end, {
    desc = "Pick among the individual Phabricator inline comments",
    nargs = "*",
    complete = status_complete,
  })
  cmd("PhabToggle", function() api.toggle() end, {
    desc = "Toggle Phabricator inline comment visibility (keeps the cache)",
  })
  cmd("PhabNext", function() api.goto_next() end, {
    desc = "Jump to the next Phabricator inline comment in this buffer",
  })
  cmd("PhabPrev", function() api.goto_prev() end, {
    desc = "Jump to the previous Phabricator inline comment in this buffer",
  })
  cmd("PhabComments", function(o)
    local args = parse(o.args)
    args.refresh = o.bang
    api.show_comments(args)
  end, {
    bang = true,
    nargs = "*",
    desc = "Show general revision comments in a float (! to refetch)",
  })
  cmd("PhabDescription", function(o)
    local args = parse(o.args)
    args.refresh = o.bang
    api.show_description(args)
  end, {
    bang = true,
    nargs = "*",
    desc = "Show the diff summary and test plan in a float (! to refetch)",
  })
  cmd("PhabComment", function(o)
    local args = parse(o.args)
    args.line1 = o.line1
    args.line2 = o.line2
    args.refresh = o.bang
    api.comment(args)
  end, {
    bang = true,
    range = true,
    nargs = "*",
    desc = "Draft an inline comment on this line / selection (! refetches the diff)",
  })
  cmd("PhabSuggest", function(o)
    local args = parse(o.args)
    args.line1 = o.line1
    args.line2 = o.line2
    args.refresh = o.bang
    api.suggest(args)
  end, {
    bang = true,
    range = true,
    nargs = "*",
    desc = "Draft an inline comment suggesting a rewrite of this line / selection",
  })
  cmd("PhabDraftEdit", function() api.draft_edit() end, {
    desc = "Re-open the unpublished draft on this line",
  })
  cmd("PhabDraftDelete", function() api.draft_delete() end, {
    desc = "Discard the unpublished draft on this line",
  })
  cmd("PhabSubmit", function(o) api.submit(parse(o.args)) end, {
    nargs = "*",
    desc = "Publish this session's inline comment drafts (asks for a cover message)",
  })
  cmd("PhabDrafts", function(o) api.drafts(parse(o.args)) end, {
    nargs = "*",
    desc = "Pick among the unpublished inline comment drafts",
  })
  cmd("PhabEditSummary", function() api.edit_summary() end, {
    desc = "Edit the diff summary (:w saves to Phabricator)",
  })
  cmd("PhabEditTestPlan", function() api.edit_test_plan() end, {
    desc = "Edit the diff test plan (:w saves to Phabricator)",
  })

  local cfg = config.get()
  local keys = cfg.keys or {}

  local function map(lhs, rhs, desc)
    if lhs and lhs ~= "" then
      vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
    end
  end

  -- Commenting and suggesting have a visual-mode meaning: the selection is the
  -- comment's line range, so the commands carry the range through.
  local function map_range(lhs, command, what)
    if not lhs or lhs == "" then return end
    vim.keymap.set("n", lhs, "<cmd>" .. command .. "<cr>",
      { silent = true, desc = "Phab: " .. what .. " on this line" })
    vim.keymap.set("x", lhs, ":" .. command .. "<cr>",
      { silent = true, desc = "Phab: " .. what .. " on this selection" })
  end

  map_range(keys.comment, "PhabComment", "comment")
  map_range(keys.suggest, "PhabSuggest", "suggest a change")

  map(keys.open_all,       function() api.open_all() end,        "Phab: files with inline comments")
  map(keys.revision,       function() api.set_revision() end,    "Phab: set revision for this worktree")
  map(keys.browser,        function() api.open_browser() end,    "Phab: open revision in browser")
  map(keys.list,           function() api.list() end,            "Phab: inline comments")
  map(keys.refresh,        function() api.refresh() end,         "Phab: refresh inline comments")
  map(keys.clear,          function() api.clear_buf() end,       "Phab: clear inline comments in buffer")
  map(keys.comments,       function() api.show_comments() end,   "Phab: revision comments")
  map(keys.description,    function() api.show_description() end, "Phab: description (summary + test plan)")
  map(keys.edit_summary,   function() api.edit_summary() end,    "Phab: edit summary")
  map(keys.edit_test_plan, function() api.edit_test_plan() end,  "Phab: edit test plan")
  map(keys.draft_edit,     function() api.draft_edit() end,      "Phab: edit the draft on this line")
  map(keys.draft_delete,   function() api.draft_delete() end,    "Phab: discard the draft on this line")
  map(keys.submit,         function() api.submit() end,          "Phab: publish inline comment drafts")
  map(keys.drafts,         function() api.drafts() end,          "Phab: unpublished drafts")
  map(keys.next,           api.goto_next,                        "Phab: next inline comment")
  map(keys.prev,           api.goto_prev,                        "Phab: previous inline comment")

  -- Visibility goes through the Snacks.toggle registry rather than a plain
  -- map, so which-key renders it with the on/off state like the <leader>u
  -- toggles. The registry only exists after snacks' setup(), hence VeryLazy.
  if keys.toggle then
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        Snacks.toggle
          .new({
            name = "Phab inline comments",
            get = function() return not api.is_hidden() end,
            set = function() api.toggle() end,
          })
          :map(keys.toggle)
      end,
    })
  end

  if cfg.auto then
    local group = vim.api.nvim_create_augroup("gaf_phab", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
      group = group,
      callback = function(args) api.on_buf(args.buf) end,
    })
  end
end

return M
