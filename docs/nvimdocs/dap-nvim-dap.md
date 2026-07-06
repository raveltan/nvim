# dap-nvim-dap
> Debug Adapter Protocol client for Neovim — language-agnostic step debugging.

**Repo:** https://github.com/mfussenegger/nvim-dap
**Local spec:** lua/plugins/dap.lua:3
**Tags:** dap debugger breakpoint step-debug adapter

## Scope
Core DAP client. Manages adapters, configurations, breakpoints, stepping, and the REPL. Our spec also wires per-language launch configs (Python, Rust via codelldb, JS/TS via pwa-node + pwa-chrome) inside `config = function()` and registers a long keymap table for stepping/breakpoint control.

## Install spec
```lua
{
  "mfussenegger/nvim-dap",
  dependencies = {
    "igorlfs/nvim-dap-view",
    "theHamsta/nvim-dap-virtual-text",
    "jay-babu/mason-nvim-dap.nvim",
    "suketa/nvim-dap-ruby",
    "Weissle/persistent-breakpoints.nvim",
    "ofirgall/goto-breakpoints.nvim",
  },
  keys = function() ... end,
  config = function() ... end,
}
```

## Common customizations
nvim-dap has no global `setup()` — you configure it by assigning to module tables:

- `dap.adapters.<name>` — adapter definition (type=`executable`|`server`, command, port, args). Typically delegated to mason-nvim-dap handlers in our setup.
- `dap.configurations.<filetype>` — list of launch entries shown by `:lua require'dap'.continue()`.
- `dap.defaults.fallback.exception_breakpoints` — control which exception classes break by default.
- `dap.defaults.fallback.terminal_win_cmd` — how the integrated terminal opens (e.g. `"belowright new"`).
- `dap.set_log_level('DEBUG')` — log file at `:lua print(vim.fn.stdpath('cache'))/dap.log`.
- `vim.fn.sign_define('DapBreakpoint', { text=..., texthl=... })` — sign appearance.

See `:help dap.txt`, `:help dap-adapter`, `:help dap-configuration`.

## Our config
- Custom highlights `DapStoppedLine`, `NvimDapVirtualText*` for tokyonight-esque palette.
- Sign overrides: `DapBreakpoint=●`, `DapBreakpointCondition=◆`, `DapStopped=▶` with `linehl=DapStoppedLine`.
- Python configs: current file, module prompt, Flask (`flask run --no-debugger --no-reload` with FLASK_APP/FLASK_DEBUG env), FastAPI (`uvicorn main:app --reload --port 8000`). All `justMyCode=false`, `integratedTerminal`.
- Rust configs (codelldb): launch prompt, launch cargo debug binary inferred from cwd basename, attach by PID.
- JS/TS configs: Jest `--runInBand` for current file, attach Chrome at `localhost:4200` (ng serve).
- GAF gate: `if vim.g.gaf then require("gaf.dap").setup_php_configuration() end` so PHP config is present even when DAP loads after a php buffer (avoids "expected not empty table" crash).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>dc` | n | `dap.continue()` | Continue |
| `<leader>di` | n | `dap.step_into()` | Step into |
| `<leader>do` | n | `dap.step_over()` | Step over |
| `<leader>dO` | n | `dap.step_out()` | Step out |
| `<leader>dt` | n | `dap.terminate()` | Terminate |
| `<leader>dl` | n | `dap.run_last()` | Run last |
| `<leader>du` | n | `dap-view.toggle()` | Toggle DAP UI |
| `<leader>de` | n/v | `:DapViewWatch` | Watch expression |

Breakpoint keymaps live in [dap-persistent-breakpoints](dap-persistent-breakpoints.md) and [dap-goto-breakpoints](dap-goto-breakpoints.md).

## GAF integration
When `vim.g.gaf` is set (`GAF=1` env), `require("gaf.dap").keys()` is appended to the keymap list and `setup_php_configuration()` runs in `config`. See [gaf-dap](gaf-dap.md).

## Links
- README: https://github.com/mfussenegger/nvim-dap
- Help: `:help dap.txt`
- Related: [dap-nvim-dap-view](dap-nvim-dap-view.md), [dap-virtual-text](dap-virtual-text.md), [dap-mason-nvim-dap](dap-mason-nvim-dap.md), [gaf-dap](gaf-dap.md)

## Notes
- Our config assigns `dap.configurations.<ft>` directly inside `config = function()`, *not* in FileType autocmds — see comment in gaf/dap.lua about the neotest-phpunit crash when configs are nil at strategy lookup time.
- `dap.adapters.codelldb` and `dap.adapters.pwa-node`/`pwa-chrome` are set inside mason-nvim-dap handlers (server type, dynamic `${port}`).
