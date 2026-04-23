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
    keys = {
      { "<leader>co", "<cmd>TSToolsOrganizeImports<cr>",       desc = "TS: organize imports" },
      { "<leader>cM", "<cmd>TSToolsAddMissingImports<cr>",     desc = "TS: add missing imports" },
      { "<leader>cU", "<cmd>TSToolsRemoveUnusedImports<cr>",   desc = "TS: remove unused imports" },
      { "<leader>cR", "<cmd>TSToolsRemoveUnused<cr>",          desc = "TS: remove unused" },
      { "<leader>cF", "<cmd>TSToolsFixAll<cr>",                desc = "TS: fix all" },
      { "<leader>cD", "<cmd>TSToolsGoToSourceDefinition<cr>",  desc = "TS: go to source definition" },
    },
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

  -- Project-wide async `tsc --noEmit` into quickfix
  {
    "dmmulroy/tsc.nvim",
    cmd = "TSC",
    opts = {
      auto_open_qflist = true,
      auto_close_qflist = false,
      use_trouble_qflist = true,
      run_as_monorepo = false,
    },
    keys = {
      { "<leader>ct", "<cmd>TSC<cr>", desc = "TS: project typecheck" },
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
        cond = {},
      },
    },
  },

  -- LSP progress/loading indicator in corner
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      progress = {
        display = {
          progress_icon = { pattern = "dots" },
          done_icon = "✓",
        },
      },
      notification = {
        window = { winblend = 0 },
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

  -- Decorated scrollbar: diagnostics, search, git hunks, marks
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    opts = {
      current_only = false,
      winblend = 50,
      handlers = {
        cursor = { enable = true },
        search = { enable = true },
        diagnostic = { enable = true },
        gitsigns = { enable = true },
        marks = { enable = true },
      },
    },
  },

  -- Code action indicator in sign column
  {
    "kosayoda/nvim-lightbulb",
    event = "LspAttach",
    opts = {
      autocmd = { enabled = true },
      sign = { enabled = true, text = "💡" },
      virtual_text = { enabled = false },
      ignore = { ft = { "neo-tree", "oil", "snacks_picker_list" } },
    },
  },

  -- Navigate code by AST: siblings, parent, child
  {
    "aaronik/treewalker.nvim",
    keys = {
      { "<A-k>", "<cmd>Treewalker Up<cr>",         mode = { "n", "v" }, desc = "AST up" },
      { "<A-j>", "<cmd>Treewalker Down<cr>",       mode = { "n", "v" }, desc = "AST down" },
      { "<A-h>", "<cmd>Treewalker Left<cr>",       mode = { "n", "v" }, desc = "AST parent" },
      { "<A-l>", "<cmd>Treewalker Right<cr>",      mode = { "n", "v" }, desc = "AST child" },
      { "<A-S-k>", "<cmd>Treewalker SwapUp<cr>",   desc = "AST swap up" },
      { "<A-S-j>", "<cmd>Treewalker SwapDown<cr>", desc = "AST swap down" },
    },
    opts = { highlight = true, highlight_duration = 250 },
  },
}
