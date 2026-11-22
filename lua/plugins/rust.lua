-- Rust support. rustaceanvim owns rust-analyzer (LSP), Cargo integration, and
-- nvim-dap glue via codelldb — do NOT add rust-analyzer to mason-lspconfig
-- (lua/plugins/lsp.lua) or it will conflict.
--
-- codelldb is installed via mason-nvim-dap (lua/plugins/dap.lua). rustaceanvim
-- auto-detects the mason path.
--
-- rust-analyzer itself is NOT installed by this config: rustaceanvim resolves
-- the `rust-analyzer` on $PATH. With rustup that is a shim which errors with
-- "Unknown binary 'rust-analyzer' in official toolchain" until the component
-- exists, so a fresh machine needs `rustup component add rust-analyzer`.
-- `:checkhealth rustaceanvim` reports this.
return {
  {
    "mrcjkb/rustaceanvim",
    -- ^9: v6-v9 breaking changes (edition opt, rust-analyzer.json, ra-multiplex,
    -- .vscode/settings.json, auto-registered capabilities, nvim <0.12) touch
    -- nothing used below; capabilities are already passed explicitly.
    version = "^9",
    -- Upstream: "This plugin is already lazy" — it is a filetype plugin, and
    -- lazy-loading it with ft = "rust" races its own ftplugin against this
    -- spec's config. No dependencies either: listing blink/dap/lspconfig here
    -- would drag the whole completion + DAP stack into startup. vim.g is set
    -- as a function so it is only evaluated when a rust buffer attaches, which
    -- is what keeps the blink require off the startup path.
    lazy = false,
    init = function()
      vim.g.rustaceanvim = function()
        local mason_pkg = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
        local codelldb_path = mason_pkg .. "/extension/adapter/codelldb"
        local liblldb_path = mason_pkg .. "/extension/lldb/lib/liblldb.dylib"
        if vim.fn.has("linux") == 1 then
          liblldb_path = mason_pkg .. "/extension/lldb/lib/liblldb.so"
        end

        return {
          tools = {
            float_win_config = { border = "rounded" },
          },
          server = {
            on_attach = function(_, bufnr)
              local function bmap(lhs, cmd, desc, mode)
                vim.keymap.set(mode or "n", lhs, function() vim.cmd.RustLsp(cmd) end,
                  { buffer = bufnr, desc = "Rust: " .. desc })
              end
              bmap("K", { "hover", "actions" }, "hover actions")
              bmap("<leader>cT", "runnables", "runnables")
              bmap("<leader>cL", "testables", "testables")
              bmap("<leader>cB", "debuggables", "debuggables")
              bmap("<leader>cX", "expandMacro", "expand macro")
              bmap("<leader>cE", "explainError", "explain error")
              bmap("<leader>cC", "openCargo", "open Cargo.toml")
              bmap("<leader>cP", "parentModule", "parent module")
              bmap("<leader>cW", "reloadWorkspace", "reload workspace")
              bmap("J", "joinLines", "join lines", { "n", "v" })
            end,
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
      end
    end,
  },
}
