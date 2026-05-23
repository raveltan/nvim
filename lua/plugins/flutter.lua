-- Flutter/Dart support. flutter-tools.nvim owns dartls (LSP), hot reload,
-- device selection, and Flutter's DAP — do NOT add dartls to mason-lspconfig
-- (lua/plugins/lsp.lua) or it will conflict.
return {
  {
    "akinsho/flutter-tools.nvim",
    ft = { "dart" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    keys = {
      { "<leader>Fr", "<cmd>FlutterRun<cr>",           desc = "Flutter run" },
      { "<leader>FR", "<cmd>FlutterReload<cr>",        desc = "Flutter hot reload" },
      { "<leader>FM", "<cmd>FlutterRestart<cr>",       desc = "Flutter hot restart" },
      { "<leader>Fq", "<cmd>FlutterQuit<cr>",          desc = "Flutter quit" },
      { "<leader>Fd", "<cmd>FlutterDevices<cr>",       desc = "Flutter devices" },
      { "<leader>Fe", "<cmd>FlutterEmulators<cr>",     desc = "Flutter emulators" },
      { "<leader>Fl", "<cmd>FlutterLogToggle<cr>",     desc = "Flutter log toggle" },
      { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Flutter outline" },
      { "<leader>Fp", "<cmd>FlutterPubGet<cr>",        desc = "Flutter pub get" },
      { "<leader>FP", "<cmd>FlutterPubUpgrade<cr>",    desc = "Flutter pub upgrade" },
      { "<leader>Fc", "<cmd>FlutterLspRestart<cr>",    desc = "Flutter LSP restart" },
    },
    opts = function()
      return {
        ui = { border = "rounded", notification_style = "native" },
        decorations = {
          statusline = { app_version = false, device = true, project_config = false },
        },
        widget_guides = { enabled = true },
        closing_tags = { highlight = "Comment", prefix = "// ", enabled = true },
        dev_log = { enabled = true, open_cmd = "tabedit" },
        outline = { open_cmd = "30vnew", auto_open = false },
        debugger = {
          enabled = true,
          run_via_dap = false,
          register_configurations = function(_)
            require("dap").configurations.dart = {
              {
                type = "dart",
                request = "launch",
                name = "Launch Flutter",
                dartSdkPath = "dart",
                flutterSdkPath = "flutter",
                program = "${workspaceFolder}/lib/main.dart",
                cwd = "${workspaceFolder}",
              },
            }
          end,
        },
        lsp = {
          color = { enabled = true, background = false, virtual_text = true },
          on_attach = function(client, _)
            client.server_capabilities.semanticTokensProvider = nil
          end,
          capabilities = require("blink.cmp").get_lsp_capabilities(),
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = "prompt",
            updateImportsOnRename = true,
            enableSnippets = true,
          },
        },
      }
    end,
  },
}
