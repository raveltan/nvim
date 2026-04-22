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
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
        tsserver_format_options = {
          allowIncompleteCompletions = false,
          allowRenameOfImportPath = false,
        },
        expose_as_code_action = "all",
        complete_function_calls = true,
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
        lsp = { "eslint" },
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
}
