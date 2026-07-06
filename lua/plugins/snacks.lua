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
            dev = vim.list_extend(
              vim.g.gaf and { "~/freelancer-dev" } or {},
              { "~/repo", "~/rails" }
            ),
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
      scratch = { enabled = false },
      dashboard = {
        enabled = true,
        sections = {
          {
            text = {
              { " █▀█ █▄░█ █░█ █ █▀▄▀█\n", hl = "SnacksDashboardHeader" },
              { " █▀▄ █░▀█ ▀▄▀ █ █░▀░█",   hl = "SnacksDashboardHeader" },
            },
            padding = 1,
          },
          {
            pane = 1,
            icon = " ",
            desc = "Edit todo.md",
            key = "t",
            action = ":e ~/todo.md",
          },
          {
            pane = 1,
            icon = " ",
            desc = "Keybinds cheatsheet",
            key = "k",
            action = ":e " .. vim.fn.stdpath("config") .. "/docs/keybinds.md",
          },
          {
            pane = 1,
            icon = " ",
            desc = "Obsidian guide",
            key = "o",
            action = ":e " .. vim.fn.stdpath("config") .. "/docs/obsidian.md",
          },
          {
            pane = 1,
            icon = "󰋽 ",
            desc = "Nvim docs (pick)",
            key = "d",
            action = ":NvimDocs",
          },
          {
            pane = 1,
            icon = " ",
            desc = "Docs index",
            key = "D",
            action = ":e " .. vim.fn.stdpath("config") .. "/docs/nvimdocs/INDEX.md",
            padding = 1,
          },
          {
            pane = 1,
            icon = " ",
            desc = "Edit snippet",
            key = "e",
            action = function() require("scissors").editSnippet() end,
          },
          {
            pane = 1,
            icon = " ",
            desc = "Add snippet",
            key = "a",
            action = function() require("scissors").addNewSnippet() end,
            padding = 1,
          },
          {
            pane = 1,
            icon = " ",
            title = "Recent Files (cwd)",
            section = "recent_files",
            cwd = true,
            limit = 5,
            indent = 2,
            padding = 1,
          },
          {
            pane = 2,
            icon = " ",
            title = "Projects",
            section = "projects",
            limit = 5,
            indent = 2,
            padding = 1,
          },
          {
            pane = 2,
            icon = " ",
            title = "Recent Files (all)",
            section = "recent_files",
            limit = 5,
            indent = 2,
            padding = 1,
          },
          { section = "startup" },
        },
      },
    },
    keys = {
      -- Find
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      -- Search
      -- Workspace grep lives on snacks (async rg, streams full results).
      -- fff live_grep is synchronous per keystroke with a time budget, so on
      -- big repos it only covers the highest-frecency files — looked like
      -- "grep only searches the current file's dir".
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep (workspace)" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, mode = { "n", "x" }, desc = "Grep word" },
      { "<leader>s.", function() Snacks.picker.grep({ dirs = { vim.fn.expand("%:p:h") } }) end, desc = "Grep in current file dir" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sc", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      -- LSP
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace symbols" },
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Go to definition" },
      { "gr", function() Snacks.picker.lsp_references() end, desc = "References" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Implementations" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Type definitions" },
      -- History / Registers
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumplist" },
      { "<leader>s/", function() Snacks.picker.search_history() end, desc = "Search history" },
      { "<leader>s:", function() Snacks.picker.command_history() end, desc = "Command history" },
      -- Find extras
      -- Tools
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>fR", function() Snacks.rename.rename_file() end, desc = "Rename file" },
    },
  },
  {
    -- Progressive file→grep seeker, built on the snacks.nvim picker.
    -- <C-e> toggles file/grep mode; each switch refines the result set.
    "2kabhishek/seeker.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = { "Seeker" },
    keys = {
      { "<leader>/", "<cmd>Seeker<cr>", desc = "Seek (progressive file → grep)" },
    },
    opts = {},
  },
}
