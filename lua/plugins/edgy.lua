return {
  -- Deterministic sidebar/bottom panel layout for trouble/dap-view/undotree
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      -- laststatus=3 (global statusline) is already set in lua/config/options.lua.
      -- Per-window identity comes from lualine's winbar instead; every ft docked
      -- below is in its disabled_filetypes.winbar list so these titles survive.
      vim.opt.splitkeep = "screen"
    end,
    opts = {
      animate = { enabled = false },
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
        -- Snacks.terminal (<leader>/) opened as a plain split outside edgy, so it had
        -- no title bar and ignored exit_when_last / close_when_all_hidden. The filter
        -- is snacks' own documented one: match only editor-relative snacks windows
        -- docked bottom, and never trouble's preview window.
        {
          ft = "snacks_terminal",
          size = { height = 0.3 },
          title = "%{b:snacks_terminal.id}: %{b:term_title}",
          filter = function(_buf, win)
            return vim.w[win].snacks_win
              and vim.w[win].snacks_win.position == "bottom"
              and vim.w[win].snacks_win.relative == "editor"
              and not vim.w[win].trouble_preview
          end,
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
