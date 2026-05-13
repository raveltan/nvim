return {
  -- Deterministic sidebar/bottom panel layout for trouble/dap-view/undotree
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      -- Required by edgy for clean layouts
      vim.opt.laststatus = 3 -- already globalstatus via lualine
      vim.opt.splitkeep = "screen"
    end,
    opts = {
      animate = { enabled = false }, -- smear-cursor + indentscope already animate
      wo = {
        winbar = true,
        winfixwidth = true,
        winfixheight = false,
        winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
        spell = false,
      },
      exit_when_last = true,
      close_when_all_hidden = true,

      bottom = {
        {
          ft = "trouble",
          title = "Trouble",
          size = { height = 0.3 },
        },
        {
          ft = "qf",
          title = "QuickFix",
          size = { height = 0.25 },
        },
        {
          ft = "dap-repl",
          title = "DAP REPL",
          size = { height = 0.3 },
        },
        {
          ft = "dap-view",
          title = "DAP",
          size = { height = 0.35 },
        },
        {
          ft = "dap-view-term",
          title = "DAP Terminal",
          size = { height = 0.3 },
        },
        {
          ft = "help",
          size = { height = 0.4 },
          filter = function(buf) return vim.bo[buf].buftype == "help" end,
        },
        {
          ft = "grug-far",
          title = "Search/Replace",
          size = { height = 0.4 },
        },
      },

      left = {
        {
          ft = "undotree",
          title = "Undotree",
          size = { width = 30 },
          pinned = false,
          open = "UndotreeToggle",
        },
        {
          ft = "diff",
          title = "Undo Diff",
          size = { height = 0.4 },
        },
      },

      keys = {
        ["q"] = function(win) win:close() end,
        ["<c-q>"] = function(win) win:hide() end,
        ["Q"] = function(win) win.view.edgebar:close() end,
      },
    },
  },
}
