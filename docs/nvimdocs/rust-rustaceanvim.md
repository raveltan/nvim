# rust-rustaceanvim
> Batteries-included Rust toolchain plugin — owns rust-analyzer LSP, Cargo, and DAP via codelldb.

**Repo:** https://github.com/mrcjkb/rustaceanvim
**Local spec:** lua/plugins/rust.lua:9
**Tags:** rust rust-analyzer lsp dap codelldb cargo clippy

## Scope
Drop-in Rust support. Replaces a manual rust-analyzer config in lspconfig and bundles `:Rust*` user commands (runnables, debuggables, expand macro, parent module, etc.). Wires nvim-dap to codelldb for breakpoint debugging. The plugin uses `vim.g.rustaceanvim` (a global table) instead of `setup()`; assignment must happen *before* the rust filetype is entered.

Rust-analyzer is **owned by this plugin** — do NOT add it to mason-lspconfig (see comment header in `rust.lua`) or two LSP clients will attach and fight over diagnostics.

## Install spec
```lua
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
    vim.g.rustaceanvim = { tools = {...}, server = {...}, dap = {...} }
  end,
}
```

## Common customizations
- `tools.float_win_config` *(table, `{ border = "single" }`)* — appearance of hover/action floats. We override to `rounded`.
- `tools.hover_actions.replace_builtin_hover` *(bool, `true`)* — whether `vim.lsp.buf.hover` is replaced by the action-enabled hover.
- `tools.code_actions.ui_select_fallback` *(bool, `false`)* — use `vim.ui.select` when telescope-ui-select etc. is missing.
- `tools.enable_clippy` *(bool, `true`)* — register `:RustLsp clippy` command.
- `server.cmd` *(table|fun, mason path)* — override rust-analyzer binary. Default auto-detects mason → cargo → rustup.
- `server.default_settings["rust-analyzer"]` *(table)* — passed through as rust-analyzer settings (see [rust-analyzer manual](https://rust-analyzer.github.io/manual.html#configuration)).
- `server.on_attach` *(fun(client, bufnr))* — usual LSP attach hook. Note: our shared LSP `on_attach` in `lua/plugins/lsp.lua` does NOT run here unless added explicitly.
- `dap.adapter` *(table)* — DAP adapter spec. We use a `server`-type adapter pointing at the codelldb binary installed by mason.
- `dap.autoload_configurations` *(bool, `true`)* — auto-register `dap.configurations.rust` from Cargo metadata.

If uncertain about a field, WebFetch https://raw.githubusercontent.com/mrcjkb/rustaceanvim/HEAD/README.md or `:help rustaceanvim`.

## Our config
- `tools.float_win_config.border = "rounded"` — matches the rest of our LSP UI.
- `server.capabilities = blink.cmp.get_lsp_capabilities()` — completion capabilities advertised to rust-analyzer.
- `server.default_settings["rust-analyzer"]`:
  - `cargo.allFeatures = true`, `loadOutDirsFromCheck = true`, `buildScripts.enable = true` — full feature set indexed, generated code surfaced.
  - `checkOnSave = true`, `check.command = "clippy"` — clippy runs on save instead of `cargo check`.
  - `procMacro.enable = true` — expand proc-macros (needed for serde/tokio etc.).
  - `inlayHints` — chaining, closing-brace (min 25 lines), parameter, and type hints **on**; binding-mode, closure return, lifetime elision, reborrow **off**; `renderColons = true`.
- `dap.adapter` — server type, dynamic `${port}`, command = `{mason}/packages/codelldb/extension/adapter/codelldb`, args wire `--liblldb` (`.dylib` on macOS, `.so` on Linux) and `--port ${port}`.

codelldb itself is installed via mason-nvim-dap — see [[dap-nvim-dap]] and [[dap-mason-nvim-dap]].

## Keymaps
No `<leader>R*` keys are defined in our spec — rustaceanvim ships `:Rust*` commands instead. Common invocations:

| Command | Action |
|---|---|
| `:RustLsp codeAction` | Grouped code actions (better than `vim.lsp.buf.code_action`) |
| `:RustLsp runnables` | Pick a `cargo run`/`cargo test` target |
| `:RustLsp debuggables` | Pick a debug target → launches codelldb via nvim-dap |
| `:RustLsp expandMacro` | Show macro expansion in a scratch buffer |
| `:RustLsp parentModule` | Jump to parent module |
| `:RustLsp openCargo` | Open `Cargo.toml` |
| `:RustLsp hover actions` | Hover with code actions inline |
| `:RustLsp renderDiagnostic` | Render the full diagnostic (rendered field) |
| `:RustAnalyzer restart` | Restart the LSP server |

Step-debug keys (`<leader>dc/di/do/...`) are the generic nvim-dap ones — see [[dap-nvim-dap]].

## Links
- README: https://github.com/mrcjkb/rustaceanvim
- Help: `:help rustaceanvim`
- rust-analyzer settings: https://rust-analyzer.github.io/manual.html#configuration
- codelldb: https://github.com/vadimcn/codelldb
- Related: [[dap-nvim-dap]], [[dap-mason-nvim-dap]], [[lsp-nvim-lspconfig]]

## Notes
- `vim.g.rustaceanvim` must be set before any rust buffer loads; `config = function()` inside a `ft = { "rust" }` lazy spec is fine because lazy.nvim runs `config` on FileType=rust before the LSP starts.
- If rust-analyzer ever appears twice in `:LspInfo`, check that `rust_analyzer` was not re-added to `ensure_installed` in `lua/plugins/lsp.lua`.
- mason path resolution is hard-coded to `vim.fn.stdpath("data") .. "/mason/packages/codelldb"`. If you change `MASON` install dir this breaks.
- liblldb extension is OS-detected (`.dylib` default, `.so` on Linux). Windows is not handled.
