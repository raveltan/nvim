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

  -- CodeCompanion — buffer-integrated AI chat / inline / cmd.
  -- Uses claude_code ACP adapter → reuses Claude Code CLI subscription auth
  -- (no ANTHROPIC_API_KEY needed). Requires `claude` CLI on PATH + logged in.
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "CodeCompanion chat toggle" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>",     mode = { "n", "v" }, desc = "CodeCompanion actions" },
      { "<leader>ai", ":CodeCompanion ",                   mode = { "n", "v" }, desc = "CodeCompanion inline" },
      { "<leader>ax", "<cmd>CodeCompanionChat Add<cr>",    mode = "v",          desc = "Add selection to chat" },
      { "<leader>aC", "<cmd>CodeCompanionCmd<cr>",         desc = "CodeCompanion cmd-line" },
    },
    opts = {
      -- claude_code ACP adapter (ships with codecompanion). Spawns
      -- @agentclientprotocol/claude-agent-acp bridge → reuses Claude Code CLI
      -- subscription auth via keychain. No API key, no env overrides needed.
      strategies = {
        chat = { adapter = "claude_code" },
        inline = { adapter = "claude_code" },
        cmd = { adapter = "claude_code" },
      },
      display = {
        chat = {
          window = {
            layout = "vertical",
            width = 0.4,
            border = "rounded",
          },
          show_settings = false,
        },
        diff = { provider = "default" },
      },
    },
  },

}
