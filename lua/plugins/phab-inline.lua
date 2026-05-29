-- Phabricator inline review comments, shown inline in nvim buffers.
-- GAF-only: vendored under <config>/phab-inline.nvim, loaded as a local plugin.
-- Activates for buffers under a D<digits> worktree dir (e.g. .../D225194/...).
return {
  {
    dir = vim.fn.stdpath("config") .. "/phab-inline.nvim",
    name = "phab-inline.nvim",
    cond = vim.g.gaf == true,
    -- Load when a file buffer opens (lazy refires the event so the
    -- BufReadPost autocmd below catches the triggering buffer) or when any
    -- :Phab* command is run.
    event = { "BufReadPost", "BufEnter" },
    cmd = {
      "PhabInlineRefresh",
      "PhabInlineClear",
      "PhabInlineOpenAll",
      "PhabInlineToggle",
      "PhabInlineNext",
      "PhabInlinePrev",
      "PhabInlineComments",
      "PhabDescription",
      "PhabEditSummary",
      "PhabEditTestPlan",
    },
    config = function()
      -- Export creds from ~/.config/phab-inline/creds.env into vim.env so the
      -- bundled scripts pick them up. Falls back to ~/.arcrc if file absent.
      require("gaf.phab").load()
      require("phab-inline").setup({
        keys = {
          open_all       = "<leader>pi", -- open every file with inline comments
          refresh        = "<leader>pr", -- refetch comments for this worktree
          clear          = "<leader>pc", -- clear decorations in this buffer
          toggle         = "<leader>pt", -- toggle decoration visibility (keeps cache)
          comments       = "<leader>pg", -- general (non-inline) revision comments float
          description    = "<leader>pd", -- diff summary + test plan float
          edit_summary   = "<leader>ps", -- edit diff summary, :w saves to Phabricator
          edit_test_plan = "<leader>pp", -- edit test plan, :w saves to Phabricator
          next           = "]p",         -- next inline comment (shadows put-with-indent)
          prev           = "[p",         -- prev inline comment (shadows put-with-indent)
        },
      })
    end,
  },
}
