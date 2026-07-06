# lsp-mason-lspconfig
> Bridges Mason package names to `nvim-lspconfig` server names and auto-enables installed servers.

**Repo:** https://github.com/mason-org/mason-lspconfig.nvim
**Local spec:** lua/plugins/lsp.lua:9
**Tags:** mason, lspconfig, ensure_installed, automatic_enable

## Scope

`mason-lspconfig` takes a list of server names (`ensure_installed`) and makes sure Mason has them installed, then — on version 2.x — calls `vim.lsp.enable()` for each one automatically so they attach to buffers. Our `nvim-lspconfig` spec registers `vim.lsp.config(name, ...)` overrides before this fires, so per-server settings flow through.

## Install spec
```lua
{
  "mason-org/mason-lspconfig.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
  opts = function()
    local servers = { "eslint", "basedpyright", "ruff", "jsonls", "yamlls",
                      "html", "cssls", "intelephense", "tailwindcss", "typos_lsp" }
    if vim.g.gaf then
      servers = require("gaf.lsp").filter_mason_servers(servers)
    end
    return { ensure_installed = servers }
  end,
}
```

## Common customizations
- `ensure_installed` *(string[], `{}`)* — Mason names of LSP servers to install on startup.
- `automatic_enable` *(boolean or `{ exclude = { ... } }`, `true` in 2.x)* — call `vim.lsp.enable()` for each installed server. Set to `false` if you want to call it manually.
- `automatic_installation` *(boolean, `false`)* — install any `nvim-lspconfig`-configured server even if it's not in `ensure_installed`. We leave this off.

(See https://github.com/mason-org/mason-lspconfig.nvim/blob/main/doc/mason-lspconfig.txt.)

## Our config

Installed servers (the union of GAF-on and GAF-off):

- `eslint` — JS/TS linting via the ESLint LS.
- `basedpyright` — Python type checker.
- `ruff` — Python lint + format LS (hover disabled, see [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)).
- `jsonls` — JSON with SchemaStore.
- `yamlls` — YAML with SchemaStore.
- `html`, `cssls` — web markup/styles.
- `intelephense` — PHP.
- `tailwindcss` — Tailwind class IntelliSense (filtered out in GAF profile).
- `typos_lsp` — Typo finder.

TypeScript is intentionally **not** in the list — `typescript-tools.nvim` owns `ts_ls` (see `lua/plugins/productivity.lua`).

## GAF integration

When `vim.g.gaf` is truthy (set by `GAF=1` env), `gaf.lsp.filter_mason_servers()` drops `tailwindcss` from `ensure_installed` because the GAF webapp doesn't use Tailwind. The function lives in `lua/gaf/lsp.lua`. See [[gaf-lsp]] for the GAF-specific LSP layer.

## Links
- README: https://github.com/mason-org/mason-lspconfig.nvim
- Related: [lsp-mason](lsp-mason.md), [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)

## Notes

`event = { "BufReadPre", "BufNewFile" }` matches `nvim-lspconfig` so server config registration happens first; otherwise `automatic_enable` would attach servers without our `vim.lsp.config()` overrides.
