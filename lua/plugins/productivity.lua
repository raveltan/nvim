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
    end,
  },

  -- Readable TS errors: translates cryptic messages AND expands collapsed types
  {
    "OlegGulevskyy/better-ts-errors.nvim",
    ft = { "typescript", "typescriptreact" },
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      keymaps = {
        toggle = "<leader>dd",
        go_to_definition = "<leader>dx",
      },
    },
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

  -- Inline reference counts above symbols (JetBrains-style)
  {
    "Wansmer/symbol-usage.nvim",
    event = "LspAttach",
    opts = {
      vt_position = "end_of_line",
      references = { enabled = true, include_declaration = false },
      definition = { enabled = false },
      implementation = { enabled = false },
      disable = {
        -- Skip typescript-tools: textDocument/references on every symbol is expensive on large TS projects.
        lsp = { "eslint", "typescript-tools" },
        filetypes = {},
        cond = { function(buf) return vim.api.nvim_buf_line_count(buf) > 1000 end },
      },
    },
  },

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

  -- REPL with line/visual/file send. For Ruby auto-picks bin/rails console
  -- when in a Rails project, else pry, else irb. Same prefix (<leader>i)
  -- works across ruby/python/lua scratch sessions.
  {
    "Vigemus/iron.nvim",
    event = "VeryLazy",
    config = function()
      local iron = require("iron.core")
      local view = require("iron.view")
      iron.setup({
        config = {
          scratch_repl = true,
          repl_definition = {
            ruby = {
              command = function()
                if vim.fn.filereadable("bin/rails") == 1 then
                  return { "bin/rails", "console" }
                elseif vim.fn.executable("pry") == 1 then
                  return { "pry" }
                end
                return { "irb" }
              end,
            },
            python = { command = { "python3" } },
            lua    = { command = { "lua" } },
          },
          repl_open_cmd = view.split.vertical.botright(0.4),
        },
        keymaps = {
          toggle_repl       = "<leader>is",
          restart_repl      = "<leader>ir",
          send_motion       = "<leader>ic",
          visual_send       = "<leader>iv",
          send_line         = "<leader>il",
          send_file         = "<leader>if",
          send_until_cursor = "<leader>iu",
          send_mark         = "<leader>im",
          mark_motion       = "<leader>iM",
          mark_visual       = "<leader>iM",
          remove_mark       = "<leader>id",
          cr                = "<leader>i<cr>",
          interrupt         = "<leader>ix",
          exit              = "<leader>iq",
          clear             = "<leader>iC",
        },
        highlight = { italic = true },
        ignore_blank_lines = true,
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

  -- Zed-style symbol picker. LSP + ctags + treesitter fallback, multi-buffer
  -- (watchtower), diagnostics picker, and call hierarchy (in/out/both).
  -- Owns <leader>ss / <leader>sS (replacing snacks.lsp_symbols).
  {
    "bassamsdata/namu.nvim",
    cmd = "Namu",
    keys = {
      { "<leader>ss", "<cmd>Namu symbols<cr>",              desc = "Symbols (Namu)" },
      { "<leader>sS", "<cmd>Namu workspace<cr>",            desc = "Workspace symbols (Namu)" },
      { "<leader>sW", "<cmd>Namu watchtower<cr>",           desc = "Symbols across open buffers" },
      { "<leader>sC", "<cmd>Namu ctags<cr>",                desc = "ctags symbols (buffer)" },
      { "<leader>sD", "<cmd>Namu diagnostics workspace<cr>", desc = "Workspace diagnostics (Namu)" },
      { "<leader>cI", "<cmd>Namu call in<cr>",              desc = "Call hierarchy: incoming" },
      { "<leader>cO", "<cmd>Namu call out<cr>",             desc = "Call hierarchy: outgoing" },
      { "<leader>cB", "<cmd>Namu call both<cr>",            desc = "Call hierarchy: both" },
    },
    opts = {
      namu_symbols = {
        enable  = true,
        options = {
          display     = { mode = "icon", padding = 2 },
          row_position = "top10",
        },
      },
      workspace      = { enable = true },
      watchtower     = { enable = true },
      diagnostics    = { enable = true },
      call_hierarchy = { enable = true },
      ctags          = { enable = true },
      ui_select      = { enable = false }, -- keep snacks.input as vim.ui.select handler
    },
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
