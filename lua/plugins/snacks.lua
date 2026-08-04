return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    init = function()
      -- Snacks.toggle is a registry, not a set of plain functions: each entry knows
      -- its own state, so which-key renders it green/yellow with an Enable/Disable
      -- description and the icon flips. Raw Snacks.zen() calls get none of that.
      -- Deferred to VeryLazy because the registry only exists after setup().
      -- Key choices: <leader>ud* is the duck group and <leader>ur is the resize
      -- submode (lua/config/keymaps.lua), so diagnostics takes <leader>ux.
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          Snacks.toggle.option("conceallevel", { off = 0, on = 2, name = "Conceal" }):map("<leader>uc")
          Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
          Snacks.toggle.line_number():map("<leader>ul")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.diagnostics():map("<leader>ux")
          Snacks.toggle.dim():map("<leader>uD")
          Snacks.toggle.zen():map("<leader>uz")
          Snacks.toggle.zoom():map("<leader>uZ")
          Snacks.toggle.profiler():map("<leader>up")
        end,
      })
    end,
    ---@type snacks.Config
    opts = {
      -- styles re-skins every Snacks surface at once (picker, notifier, input, zen,
      -- lazygit, blame). Only the pieces that clash with a transparent theme are
      -- overridden; borders already come from 'winborder' globally.
      styles = {
        notification = {
          -- style="fancy" ships winblend=5; any blend over a transparent Normal
          -- muddies the notification against whatever buffer text is behind it.
          wo = { winblend = 0 },
        },
      },
      image = { enabled = true },
      picker = {
        enabled = true,
        -- Was unset (= the two-pane "default" layout for everything). Per-source
        -- layouts instead: telescope-style for anything you read a preview from,
        -- ivy (bottom dock, full-width preview) for greps where the match needs
        -- surrounding lines, vscode (centered, previewless) for flat lists.
        -- cycle=true makes j/k wrap at the ends of the result list.
        layout = { preset = "telescope", cycle = true },
        sources = {
          grep = { layout = { preset = "ivy" } },
          grep_word = { layout = { preset = "ivy" } },
          grep_buffers = { layout = { preset = "ivy" } },
          lines = { layout = { preset = "ivy" } },
          buffers = { layout = { preset = "vscode" } },
          commands = { layout = { preset = "vscode" } },
          command_history = { layout = { preset = "vscode" } },
          keymaps = { layout = { preset = "vscode" } },
          registers = { layout = { preset = "vscode" } },
          marks = { layout = { preset = "vscode" } },
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
      -- Off: comfy-line-numbers.nvim owns the global 'statuscolumn' (it overwrites
      -- this on BufReadPre anyway). One owner, no fight over the number column.
      statuscolumn = { enabled = false },
      input = { enabled = true },
      rename = { enabled = true },
      bigfile = { enabled = true, size = 500 * 1024 },
      words = { enabled = false },
      -- style "fancy" = bordered box with an icon + title row (default "compact"
      -- is a single unbordered line). top_down stays true so notifications never
      -- land on top of fidget's bottom-right LSP progress window.
      notifier = { enabled = true, style = "fancy", top_down = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scratch = { enabled = false },
      -- Distraction-free writing/reading. zen hides gutters + centers the buffer;
      -- zen.zoom keeps the UI but maximizes the current window inside the layout
      -- (works with edgy panels open, unlike <C-w>o).
      zen = { enabled = true },
      dim = { enabled = true },
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
      -- Terminal — docked bottom split, toggles hide/show (same instance each
      -- time; <esc><esc> for normal mode inside it, then <leader>/ hides).
      { "<leader>/", function()
          Snacks.terminal.toggle(nil, { win = { position = "bottom", height = 0.3 } })
      end, desc = "Toggle terminal (bottom)" },
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumplist" },
      { "<leader>s/", function() Snacks.picker.search_history() end, desc = "Search history" },
      { "<leader>s:", function() Snacks.picker.command_history() end, desc = "Command history" },
      -- Find extras
      -- Tools
      -- UI toggles live in the Snacks.toggle registry below, not here — the registry
      -- is what gives which-key the on/off color, the icon swap and the notify.
      { "<leader>uN", function() Snacks.notifier.show_history() end, desc = "Notification history" },
      -- Tools
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>fR", function() Snacks.rename.rename_file() end, desc = "Rename file" },
    },
  },
}
