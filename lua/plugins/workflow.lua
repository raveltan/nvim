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

  -- Git worktree switcher (chdirs into selected worktree)
  {
    "polarmutex/git-worktree.nvim",
    version = "^2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>gwl",
        function()
          local wt = require("git-worktree")
          -- Simple picker using vim.ui.select
          local branches = vim.fn.systemlist("git worktree list")
          vim.ui.select(branches, { prompt = "Switch worktree" }, function(choice)
            if not choice then return end
            local path = choice:match("^(%S+)")
            if path then wt.switch_worktree(path) end
          end)
        end,
        desc = "List / switch worktree",
      },
      {
        "<leader>gwc",
        function()
          vim.ui.input({ prompt = "New worktree path: " }, function(path)
            if not path or path == "" then return end
            vim.ui.input({ prompt = "Upstream branch: " }, function(branch)
              if not branch or branch == "" then return end
              require("git-worktree").create_worktree(path, branch)
            end)
          end)
        end,
        desc = "Create worktree",
      },
      {
        "<leader>gwd",
        function()
          vim.ui.input({ prompt = "Delete worktree path: " }, function(path)
            if not path or path == "" then return end
            require("git-worktree").delete_worktree(path)
          end)
        end,
        desc = "Delete worktree",
      },
    },
    config = function()
      require("git-worktree").setup({})
      local Hooks = require("git-worktree.hooks")
      Hooks.register(Hooks.type.SWITCH, function(path, _prev_path)
        vim.notify("Worktree: " .. path, vim.log.levels.INFO)
      end)
    end,
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
