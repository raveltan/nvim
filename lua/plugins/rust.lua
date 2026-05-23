-- Rust support. rustaceanvim owns rust-analyzer (LSP), Cargo integration, and
-- nvim-dap glue via codelldb — do NOT add rust-analyzer to mason-lspconfig
-- (lua/plugins/lsp.lua) or it will conflict.
--
-- codelldb is installed via mason-nvim-dap (lua/plugins/dap.lua). rustaceanvim
-- auto-detects the mason path.
return {
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
      "mfussenegger/nvim-dap",
    },
    config = function()
      local mason_pkg = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
      local codelldb_path = mason_pkg .. "/extension/adapter/codelldb"
      local liblldb_path = mason_pkg .. "/extension/lldb/lib/liblldb.dylib"
      if vim.fn.has("linux") == 1 then
        liblldb_path = mason_pkg .. "/extension/lldb/lib/liblldb.so"
      end

      vim.g.rustaceanvim = {
        tools = {
          float_win_config = { border = "rounded" },
        },
        server = {
          capabilities = require("blink.cmp").get_lsp_capabilities(),
          default_settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                buildScripts = { enable = true },
              },
              checkOnSave = true,
              check = { command = "clippy" },
              procMacro = { enable = true },
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "never" },
                lifetimeElisionHints = { enable = "never" },
                parameterHints = { enable = true },
                reborrowHints = { enable = "never" },
                renderColons = true,
                typeHints = { enable = true },
              },
            },
          },
        },
        dap = {
          adapter = {
            type = "server",
            port = "${port}",
            host = "127.0.0.1",
            executable = {
              command = codelldb_path,
              args = { "--liblldb", liblldb_path, "--port", "${port}" },
            },
          },
        },
      }
    end,
  },
}
