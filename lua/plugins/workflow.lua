return {
  -- Task runner
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerShell", "OverseerToggle", "OverseerTaskAction", "OverseerOpen", "OverseerClose" },
    keys = {
      { "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>oc", "<cmd>OverseerShell<cr>", desc = "Run shell command" },
      {
        "<leader>ol",
        function()
          local task_list = require("overseer.task_list")
          local action_util = require("overseer.action_util")
          local tasks = task_list.list_tasks({
            unique = true,
            sort = task_list.sort_finished_recently,
            include_ephemeral = true,
          })
          if #tasks == 0 then
            vim.notify("No tasks available", vim.log.levels.WARN)
            return
          end
          vim.ui.select(tasks, {
            prompt = "Open task (float)",
            kind = "overseer_task",
            format_item = function(t)
              return t.name
            end,
          }, function(task)
            if task then
              action_util.run_task_action(task, "open float")
            end
          end)
        end,
        desc = "Open task in float",
      },
      {
        "<leader>od",
        function()
          local task_list = require("overseer.task_list")
          local action_util = require("overseer.action_util")
          local tasks = task_list.list_tasks({
            unique = true,
            sort = task_list.sort_finished_recently,
            include_ephemeral = true,
          })
          if #tasks == 0 then
            vim.notify("No tasks available", vim.log.levels.WARN)
            return
          end
          vim.ui.select(tasks, {
            prompt = "Dispose task",
            kind = "overseer_task",
            format_item = function(t)
              return t.name
            end,
          }, function(task)
            if task then
              action_util.run_task_action(task, "dispose")
            end
          end)
        end,
        desc = "Dispose task",
      },
    },
    config = function()
      local disable_template_modules = {}
      if not vim.g.gaf then
        table.insert(disable_template_modules, "^overseer%.template%.user%.")
      end
      require("overseer").setup({
        dap = true,
        disable_template_modules = disable_template_modules,
        task_list = {
          direction = "bottom",
          min_height = 8,
          max_height = { 20, 0.2 },
          keymaps = {
            ["<CR>"] = { "keymap.open", opts = { dir = "float" }, desc = "Open task output in float" },
            ["o"] = { "keymap.open", opts = { dir = "float" }, desc = "Open task output in float" },
          },
        },
        component_aliases = {
          default = {
            { "open_output", on_start = "always", direction = "float", focus = true },
            "on_exit_set_status",
            "on_complete_notify",
            { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
          },
        },
      })
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
