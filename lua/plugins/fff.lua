return {
  {
    "dmtrKovalenko/fff.nvim",
    version = "*",
    build = function() require("fff.download").download_or_build_binary() end,
    cmd = { "FFFScan", "FFFRefreshGit", "FFFClearCache", "FFFHealth", "FFFDebug", "FFFOpenLog" },
    keys = {
      { "<leader><leader>", function() require("fff").find_files() end, desc = "Find files" },
      { "<leader>fo", function()
          -- %:p:h = current file's dir; fall back to cwd for unnamed buffers.
          local dir = vim.fn.expand("%:p:h")
          if dir == "" then dir = vim.fn.getcwd() end
          vim.ui.open(dir)
        end, desc = "Open file dir in Finder" },
      -- Workspace grep (<leader>sg/sw/s.) moved to snacks.picker — fff's
      -- synchronous time-budgeted grep can't cover large repos per keystroke.
      { "<leader>sz", function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end, desc = "Fuzzy grep (frecency-first, partial on big repos)" },
    },
    opts = {
      prompt = "  ",
      title = " Files",
      max_results = 100,
      layout = {
        height = 0.85,
        width = 0.85,
        prompt_position = "top",
        preview_position = "right",
        preview_size = 0.55,
        flex = { size = 130, wrap = "top" },
      },
      preview = { line_numbers = true },
      keymaps = {
        focus_list = "<C-l>",
        focus_preview = "<C-p>",
        preview_scroll_up = "<M-u>",
      },
      frecency = { enabled = true },
      history = { enabled = true },
      grep = { smart_case = true, time_budget_ms = 200 },
    },
  },
}
