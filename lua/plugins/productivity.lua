return {
  -- TypeScript LSP: faster than vtsls/ts_ls, TS-specific commands
  -- Ports settings from the previous vtsls config in lsp.lua
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {
      settings = {
        tsserver_file_preferences = {
          importModuleSpecifierPreference = "relative",
          includePackageJsonAutoImports = "auto",
          includeInlayParameterNameHints = "none",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = false,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = false,
          includeInlayEnumMemberValueHints = false,
        },
        tsserver_format_options = {
          allowIncompleteCompletions = false,
          allowRenameOfImportPath = false,
        },
        expose_as_code_action = { "fix_all", "add_missing_imports", "remove_unused" },
        complete_function_calls = false,
        include_completions_with_insert_text = true,
        code_lens = "off",
        disable_member_code_lens = true,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        callback = function(ev)
          local opts = { buffer = ev.buf, silent = true }
          local map = vim.keymap.set
          map("n", "<leader>co", "<cmd>TSToolsOrganizeImports<cr>",      vim.tbl_extend("force", opts, { desc = "TS: organize imports" }))
          map("n", "<leader>cM", "<cmd>TSToolsAddMissingImports<cr>",    vim.tbl_extend("force", opts, { desc = "TS: add missing imports" }))
          map("n", "<leader>cU", "<cmd>TSToolsRemoveUnusedImports<cr>",  vim.tbl_extend("force", opts, { desc = "TS: remove unused imports" }))
          map("n", "<leader>cR", "<cmd>TSToolsRemoveUnused<cr>",         vim.tbl_extend("force", opts, { desc = "TS: remove unused" }))
          map("n", "<leader>cF", "<cmd>TSToolsFixAll<cr>",               vim.tbl_extend("force", opts, { desc = "TS: fix all" }))
          map("n", "<leader>cD", "<cmd>TSToolsGoToSourceDefinition<cr>", vim.tbl_extend("force", opts, { desc = "TS: go to source definition" }))
        end,
      })

      -- Organize + remove unused imports on save (TS/JS only)
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        group = vim.api.nvim_create_augroup("ts_organize_on_save", { clear = true }),
        callback = function()
          if vim.g.disable_ts_organize_on_save then return end
          vim.notify("TS: organizing imports…", vim.log.levels.INFO, { title = "Save" })
          pcall(vim.cmd, "TSToolsAddMissingImports sync")
          pcall(vim.cmd, "TSToolsRemoveUnusedImports sync")
        end,
      })
    end,
  },

  -- Auto-convert "..." to `...` when typing ${
  {
    "axelvc/template-string.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {
      filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      jsx_brackets = true,
      remove_template_string = true,
    },
  },

  -- JSON/YAML schemas: package.json, tsconfig, composer.json, GitHub Actions, etc.
  -- Consumed by jsonls/yamlls in lsp.lua
  { "b0o/SchemaStore.nvim", lazy = true, version = false },

  -- Break bad habits: blocks hjkl spam and arrow keys, nudges toward real motions
  {
    "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      max_count = 4,
      disable_mouse = false,
      restriction_mode = "hint",
      disabled_filetypes = {
        "qf", "netrw", "NvimTree", "lazy", "mason", "oil", "help", "trouble",
        "TelescopePrompt", "snacks_picker_input", "snacks_picker_list",
        "dbee", "dbui", "dap-repl", "dapui_scopes", "dapui_breakpoints",
        "dapui_stacks", "dapui_watches", "dapui_console", "aerial",
      },
    },
  },

  -- Database client: connect/inspect/query Postgres/MySQL/SQLite from inside nvim.
  -- vim-dadbod is the engine, dadbod-ui is the file-tree UI, dadbod-completion
  -- gives column/table completion inside SQL buffers via blink.cmp/omnifunc.
  --
  -- Connections: drop URLs into ~/.local/share/db_ui/connections.json or set
  -- vim.g.dbs = { rails_dev = "postgresql://..." } in a project-local config.
  {
    "tpope/vim-dadbod",
    cmd = { "DB" },
    dependencies = {
      {
        "kristijanhusak/vim-dadbod-ui",
        cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
        init = function()
          vim.g.db_ui_use_nerd_fonts          = 1
          vim.g.db_ui_show_database_icon      = 1
          vim.g.db_ui_force_echo_notifications = 1
          vim.g.db_ui_win_position            = "left"
          vim.g.db_ui_winwidth                = 40
          vim.g.db_ui_save_location           = vim.fn.stdpath("data") .. "/db_ui"
          vim.g.db_ui_use_nvim_notify         = 1
          -- Rails-aware: auto-load db/structure.sql + config/database.yml is read
          -- by db_ui via :Rails detection (works without vim-rails too).
          vim.g.db_ui_auto_execute_table_helpers = 1
        end,
      },
      "kristijanhusak/vim-dadbod-completion",
    },
    keys = {
      { "<leader>Du", "<cmd>DBUIToggle<cr>",         desc = "DB: toggle UI" },
      { "<leader>Df", "<cmd>DBUIFindBuffer<cr>",     desc = "DB: find buffer" },
      { "<leader>Da", "<cmd>DBUIAddConnection<cr>",  desc = "DB: add connection" },
      { "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>",   desc = "DB: rename buffer" },
      { "<leader>Dq", "<cmd>DBUILastQueryInfo<cr>",  desc = "DB: last query info" },
    },
    config = function()
      -- Wire dadbod-completion into SQL buffers. blink.cmp picks up omnifunc.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          vim.bo.omnifunc = "vim_dadbod_completion#omni"
        end,
      })
    end,
  },

  -- Navigate code by AST: siblings, parent, child.
  -- NOTE: <A-j>/<A-k> reserved for move-line (see config/keymaps.lua); using
  -- <leader>n* prefix here to avoid clobbering that and Treewalker's own
  -- defaults <C-h/j/k/l> (those collide with vim-tmux-navigator window nav).
  {
    "aaronik/treewalker.nvim",
    keys = {
      { "<leader>nk", "<cmd>Treewalker Up<cr>",         mode = { "n", "v" }, desc = "AST up" },
      { "<leader>nj", "<cmd>Treewalker Down<cr>",       mode = { "n", "v" }, desc = "AST down" },
      { "<leader>nh", "<cmd>Treewalker Left<cr>",       mode = { "n", "v" }, desc = "AST parent" },
      { "<leader>nl", "<cmd>Treewalker Right<cr>",      mode = { "n", "v" }, desc = "AST child" },
      { "<leader>nK", "<cmd>Treewalker SwapUp<cr>",     desc = "AST swap up" },
      { "<leader>nJ", "<cmd>Treewalker SwapDown<cr>",   desc = "AST swap down" },
    },
    opts = { highlight = true, highlight_duration = 250 },
  },

  -- Inline lens above functions (between phpDoc and function declaration).
  -- Only complexity + last_author — no LSP reference/blame storms.
  {
    "oribarilan/lensline.nvim",
    event = "LspAttach",
    opts = {
      profiles = {
        {
          name = "default",
          providers = {
            { name = "last_author",  enabled = true },
            { name = "complexity",   enabled = true, min_level = "S" },
          },
          style = {
            placement = "above",
            prefix = "┃ ",
            separator = " • ",
            use_nerdfont = true,
          },
        },
      },
      limits = {
        exclude = {
          "lazy", "mason", "TelescopePrompt", "neo-tree", "trouble",
          "help", "qf", "snacks_picker_list", "snacks_picker_input",
        },
        max_lines = 1000,
      },
    },
  },

}
