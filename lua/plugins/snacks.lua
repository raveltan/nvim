return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      image = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          projects = {
            dev = { "~/freelancer-dev", "~/repo", "~/rails" },
            patterns = { ".git", "Gemfile", "composer.json", "pyproject.toml", "requirements.txt", "Pipfile", "setup.py", "package.json" },
          },
        },
      },
      lazygit = { enabled = true },
      terminal = { enabled = true },
      indent = { enabled = true, animate = { enabled = false } },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
      input = { enabled = true },
      rename = { enabled = true },
      bigfile = { enabled = true, size = 500 * 1024 },
      words = { enabled = false },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scratch = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.picker.files({cwd = vim.fn.stdpath('config')})" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          {
            text = {
              { " ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗\n", hl = "SnacksDashboardHeader" },
              { " ████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║\n", hl = "SnacksDashboardHeader" },
              { " ██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║\n", hl = "SnacksDashboardHeader" },
              { " ██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║\n", hl = "SnacksDashboardHeader" },
              { " ██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║\n", hl = "SnacksDashboardHeader" },
              { " ╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝",   hl = "SnacksDashboardHeader" },
            },
            padding = 1,
          },
          {
            pane = 1,
            icon = " ",
            title = "Recent Files",
            section = "recent_files",
            cwd = true,
            indent = 2,
            padding = 1,
          },
          {
            pane = 1,
            icon = " ",
            title = "Quick Actions",
            section = "keys",
            indent = 2,
            padding = 1,
          },
          {
            pane = 1,
            section = "startup",
          },
        },
      },
    },
    keys = {
      -- Find
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      -- Search
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer lines" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sc", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume last picker" },
      -- LSP (document/workspace symbols handled by namu.nvim — see productivity.lua)
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Go to definition" },
      { "gr", function() Snacks.picker.lsp_references() end, desc = "References" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Implementations" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Type definitions" },
      -- Git
      { "<leader>gc", function() Snacks.picker.git_log() end, desc = "Git log" },
      -- History / Registers
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumplist" },
      { "<leader>s/", function() Snacks.picker.search_history() end, desc = "Search history" },
      { "<leader>s:", function() Snacks.picker.command_history() end, desc = "Command history" },
      -- Find extras
      -- Tools
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>/", function() Snacks.terminal.toggle() end, mode = { "n", "t" }, desc = "Toggle terminal" },
      { "<leader>fR", function() Snacks.rename.rename_file() end, desc = "Rename file" },
      -- Scratch (project-scoped scratchpad, persisted under stdpath('data'))
      { "<leader>.",  function() Snacks.scratch() end,        desc = "Toggle scratch buffer" },
      { "<leader>fs", function() Snacks.scratch.select() end, desc = "Select scratch buffer" },
    },
  },
}
