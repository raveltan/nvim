# dap-mason-nvim-dap
> Bridge mason.nvim and nvim-dap — auto-install and auto-configure debug adapters.

**Repo:** https://github.com/jay-babu/mason-nvim-dap.nvim
**Local spec:** lua/plugins/dap.lua:54
**Tags:** mason dap adapter installation js-debug codelldb

## Scope
Ensures debug adapters listed in `ensure_installed` are pulled by mason, then runs per-adapter handlers that register them with nvim-dap (`dap.adapters.*`). We override the `js-debug-adapter` and `codelldb` handlers to use the `type = "server"` pattern with dynamic ports.

## Install spec
```lua
{
  "jay-babu/mason-nvim-dap.nvim",
  dependencies = { "mason-org/mason.nvim" },
  opts = {
    ensure_installed = { "python", "php", "js", "codelldb" },
    automatic_installation = true,
    handlers = {
      function(config) require("mason-nvim-dap").default_setup(config) end,
      ["js"] = function()
        local dap = require("dap")
        local server = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
        for _, name in ipairs({ "pwa-node", "pwa-chrome" }) do
          dap.adapters[name] = {
            type = "server", host = "localhost", port = "${port}",
            executable = { command = "node", args = { server, "${port}" } },
          }
        end
      end,
      ["codelldb"] = function()
        local dap = require("dap")
        local cmd = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb"
        dap.adapters.codelldb = {
          type = "server", port = "${port}",
          executable = { command = cmd, args = { "--port", "${port}" } },
        }
      end,
    },
  },
}
```

## Common customizations
- `ensure_installed` *(string[])* — mason package names of DAP adapters to install on startup.
- `automatic_installation` *(bool|`{exclude=…}`, default `false`)* — install any adapter referenced by `dap.configurations` that isn't installed yet. Pass `{ exclude = {"foo"} }` for selective.
- `handlers` *(table)* — keyed by mason package name. The unnamed function entry is the default handler applied when no specific handler exists; per-package keys override it. Inside a handler, call `require("mason-nvim-dap").default_setup(config)` to keep default behavior plus customizations.

See `:help mason-nvim-dap-settings`.

## Our config
- `ensure_installed = { "python", "php", "js", "codelldb" }` — covers Python, PHP (xdebug for GAF), JS/TS (pwa-node + pwa-chrome via `js-debug-adapter`), Rust (codelldb). Handler keys and `ensure_installed` accept **dap source names** (`js`, not the mason package `js-debug-adapter`) — using the mason package name as a handler key raises `Received handler for unknown dap source name`.
- `automatic_installation = true` — saves a manual `:MasonInstall` after editing configs.
- `js` handler — registers *both* `pwa-node` and `pwa-chrome` against the same `dapDebugServer.js`. Default handler only sets one; we need both for our Jest + Chrome attach configs.
- `codelldb` handler — explicit server-port wiring (`--port ${port}`); default mason setup uses stdin/stdout which is less reliable for Rust attaches.

## Keymaps
None.

## Links
- README: https://github.com/jay-babu/mason-nvim-dap.nvim
- Related: [dap-nvim-dap](dap-nvim-dap.md), [dap-nvim-dap-ruby](dap-nvim-dap-ruby.md)

## Notes
- `${port}` is a magic string replaced by nvim-dap at session start — do not substitute it manually.
- PHP adapter ships its own `php` package (vscode-php-debug) and is auto-wired by `default_setup`; our `dap.configurations.php` lives in [gaf-dap](gaf-dap.md).
- Ruby is *not* listed — it's handled by [dap-nvim-dap-ruby](dap-nvim-dap-ruby.md) (not via mason).
