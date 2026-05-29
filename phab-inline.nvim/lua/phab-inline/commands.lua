-- User-facing wiring: :PhabInline* commands, optional keymaps, and the
-- BufReadPost/BufEnter autocmd.

local config = require("phab-inline.config")

local M = {}

local function status_complete()
  return { "incomplete", "done", "all" }
end

-- `api` is the public phab-inline module table.
function M.install(api)
  vim.api.nvim_create_user_command(
    "PhabInlineRefresh",
    function(o) api.refresh({ status = o.args ~= "" and o.args or nil }) end,
    {
      desc = "Refetch Phabricator inline comments for current worktree",
      nargs = "?",
      complete = status_complete,
    }
  )
  vim.api.nvim_create_user_command(
    "PhabInlineClear",
    function() api.clear_buf() end,
    { desc = "Clear Phabricator inline comment decorations in current buffer" }
  )
  vim.api.nvim_create_user_command(
    "PhabInlineOpenAll",
    function(o) api.open_all({ status = o.args ~= "" and o.args or nil }) end,
    {
      desc = "Open all files with Phabricator inline comments in current worktree",
      nargs = "?",
      complete = status_complete,
    }
  )
  vim.api.nvim_create_user_command(
    "PhabInlineToggle",
    function() api.toggle() end,
    { desc = "Toggle Phabricator inline comment visibility (keeps cache)" }
  )
  vim.api.nvim_create_user_command(
    "PhabInlineNext",
    function() api.goto_next() end,
    { desc = "Jump to next Phabricator inline comment in current buffer" }
  )
  vim.api.nvim_create_user_command(
    "PhabInlinePrev",
    function() api.goto_prev() end,
    { desc = "Jump to previous Phabricator inline comment in current buffer" }
  )
  vim.api.nvim_create_user_command(
    "PhabInlineComments",
    function(o) api.show_comments({ refresh = o.bang }) end,
    {
      bang = true,
      desc = "Show non-inline revision comments in a float (! to refetch)",
    }
  )
  vim.api.nvim_create_user_command(
    "PhabDescription",
    function(o) api.show_description({ refresh = o.bang }) end,
    {
      bang = true,
      desc = "Show diff summary and test plan in a float (! to refetch)",
    }
  )
  vim.api.nvim_create_user_command(
    "PhabEditSummary",
    function() api.edit_summary() end,
    { desc = "Open diff summary for editing (:w saves to Phabricator)" }
  )
  vim.api.nvim_create_user_command(
    "PhabEditTestPlan",
    function() api.edit_test_plan() end,
    { desc = "Open diff test plan for editing (:w saves to Phabricator)" }
  )

  local cfg = config.get()

  if cfg.keys then
    local function map(lhs, rhs, desc)
      if lhs and lhs ~= "" then
        vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
      end
    end
    map(cfg.keys.open_all, api.open_all,                   "Phab: open all files with inline comments")
    map(cfg.keys.refresh,  api.refresh,                    "Phab: refresh inline comments")
    map(cfg.keys.clear,    function() api.clear_buf() end,  "Phab: clear inline comments in buffer")
    map(cfg.keys.toggle,   function() api.toggle() end,        "Phab: toggle inline comment visibility")
    map(cfg.keys.comments,      function() api.show_comments() end,    "Phab: show non-inline revision comments")
    map(cfg.keys.description,    function() api.show_description() end, "Phab: show diff summary and test plan")
    map(cfg.keys.edit_summary,   function() api.edit_summary() end,     "Phab: edit diff summary")
    map(cfg.keys.edit_test_plan, function() api.edit_test_plan() end,    "Phab: edit diff test plan")
    map(cfg.keys.next,           api.goto_next,                         "Phab: jump to next inline comment")
    map(cfg.keys.prev,           api.goto_prev,                         "Phab: jump to previous inline comment")
  end

  if cfg.auto then
    local group = vim.api.nvim_create_augroup("phab_inline", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
      group = group,
      callback = function(args) api.on_buf(args.buf) end,
    })
  end
end

return M
