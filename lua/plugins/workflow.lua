return {
  -- Task runner
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerShell", "OverseerToggle", "OverseerTaskAction", "OverseerOpen", "OverseerClose" },
    keys = {
      { "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>oc", "<cmd>OverseerShell<cr>", desc = "Run shell command" },
      { "<leader>ot", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
      { "<leader>ol", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
    },
    opts = {
      dap = true,
      template_dirs = { "overseer.template.user" },
      task_list = {
        direction = "bottom",
        min_height = 8,
        max_height = { 20, 0.2 },
      },
    },
  },

  -- Session management
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Select session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save current session" },
    },
  },

  -- Claude Code terminal toggle
  {
    "greggh/claude-code.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeContinue", "ClaudeCodeResume", "ClaudeCodeVerbose" },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
      { "<leader>aC", "<cmd>ClaudeCodeContinue<cr>", desc = "Claude Code continue" },
      { "<leader>ar", "<cmd>ClaudeCodeResume<cr>", desc = "Claude Code resume" },
      { "<leader>av", "<cmd>ClaudeCodeVerbose<cr>", desc = "Claude Code verbose" },
    },
    opts = {
      window = {
        split_ratio = 0.4,
        position = "vertical",
        enter_insert = true,
        start_in_normal_mode = false,
        hide_numbers = true,
        hide_signcolumn = true,
      },
      refresh = {
        enable = true,
        updatetime = 100,
        timer_interval = 1000,
        show_notifications = true,
      },
      git = { use_git_root = true },
      command = "claude",
    },
  },

}
