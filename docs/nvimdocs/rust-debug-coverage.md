# rust-debug-coverage
> Debug Rust (codelldb) + coverage (cargo-llvm-cov). Two debug paths — rustaceanvim `:RustLsp debuggables` *or* generic nvim-dap configs.

**Local specs:** lua/plugins/dap.lua:170-204, lua/plugins/rust.lua (rustaceanvim DAP), lua/plugins/test.lua:96-98 (neotest-rust), lua/config/neotest-coverage.lua:31-41, lua/plugins/coverage.lua:51-53
**Tags:** rust codelldb cargo-llvm-cov lcov rustaceanvim neotest

## Scope
codelldb installed via mason-nvim-dap with a `type = "server"` adapter (dynamic `${port}`). Two debug entry points coexist:
1. **rustaceanvim** — `:RustLsp debuggables` picks a Cargo target and launches via its own DAP wiring (`dap.autoload_configurations = true`).
2. **Generic nvim-dap** — three manual `dap.configurations.rust` entries in `lua/plugins/dap.lua:170-204`.

Coverage uses `cargo-llvm-cov` → lcov.

## Debug — app / binaries
| Action | Key / Command |
|---|---|
| Pick a runnable / debuggable | `:RustLsp debuggables` (preferred) |
| Pick generic launch | `<leader>dc` |
| Step / terminate | `<leader>di / do / dO / dt` |
| Run last | `<leader>dl` |
| UI panel | `<leader>du` |
| BP toggle / cond / clear | `<leader>db` / `<leader>dB` / `<leader>dC` |
| Next / prev BP | `]b` / `[b` |
| Watch expr | `<leader>de` |

Generic configs (`lua/plugins/dap.lua:170-204`):
1. **codelldb: launch executable (prompt)** — prompts for path under `target/debug/`.
2. **codelldb: launch cargo build (debug profile)** — infers binary from cwd basename: `target/debug/${basename}`.
3. **codelldb: attach to PID** — prompts for PID.

`:RustLsp debuggables` is usually better — it knows about test binaries and examples.

## Debug — tests
neotest-rust adapter (`lua/plugins/test.lua:96-98`):

```lua
require("neotest-rust")({ args = { "--no-capture" } })
```

| Action | Key |
|---|---|
| Debug nearest | `<leader>td` |
| Debug last | `<leader>tL` |
| Run nearest | `<leader>tr` |
| Run file | `<leader>tf` |

`--no-capture` so `println!` reaches the output panel.

## Coverage — wired
`<leader>tc` / `<leader>tC` → `lua/config/neotest-coverage.lua:31-41`:

```lua
elseif ft == "rust" then
  coverage_rel = "coverage/lcov.info"
  run_env = {
    CARGO_LLVM_COV = "1",
    CARGO_LLVM_COV_TARGET_DIR = "target/llvm-cov-target",
    LLVM_COV_FLAGS = "--lcov --output-path=coverage/lcov.info",
  }
  markers = { "Cargo.toml", ".git" }
```

Flow: env vars instruct cargo-llvm-cov to instrument the build (separate target dir to avoid clashing with normal `cargo test`); on test exit, lcov is dumped to `coverage/lcov.info` → polling timer → `:CoverageLoad` + `:CoverageShow`.

`lua/plugins/coverage.lua:51-53` overrides the plugin default to read `coverage/lcov.info`.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show) |
| `<leader>tV` | `:CoverageSummary` |

Manual: `cargo llvm-cov --lcov --output-path coverage/lcov.info` then `:Coverage`.

## Prereqs
- `rustup component add llvm-tools-preview`
- `cargo install cargo-llvm-cov`
- codelldb auto-installed by mason (`ensure_installed = { ..., "codelldb" }`).
- rust-analyzer auto-installed by rustaceanvim's bundled lookup (not via mason — see [[rust-rustaceanvim]]).

## Gotchas
- **Two DAP wirings** for rust — rustaceanvim's autoloaded `dap.configurations.rust` is overwritten by our manual block in `lua/plugins/dap.lua:170-204` at config time. If `:RustLsp debuggables` stops finding targets, check whether autoload is being clobbered (it shouldn't — rustaceanvim builds configs on demand, not at startup).
- `CARGO_LLVM_COV_TARGET_DIR` is **separate** from `target/` to avoid recompiling everything when toggling coverage. First coverage run on a project is slow.
- codelldb mason path: `vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb"`. If you change mason install dir, both `lua/plugins/dap.lua` and `lua/plugins/rust.lua` adapter wiring break.
- liblldb extension is OS-detected in `rust.lua` (`.dylib` macOS, `.so` Linux). Windows not handled.
- `--no-capture` is a neotest-rust flag — does NOT correspond directly to `cargo test -- --nocapture` (it's the adapter's way of forwarding).
- macOS Apple Silicon: codelldb sometimes needs `xattr -dr com.apple.quarantine` on first install if Gatekeeper quarantines it.

## Links
- Related: [[rust-rustaceanvim]], [[dap-nvim-dap]], [[dap-mason-nvim-dap]], [[test-neotest-adapters]], [[coverage]], [[config-neotest-coverage]]
- codelldb: https://github.com/vadimcn/codelldb
- cargo-llvm-cov: https://github.com/taiki-e/cargo-llvm-cov
- neotest-rust: https://github.com/rouge8/neotest-rust
