# gaf-overview
> High-level guide to the GAF (Freelancer) Neovim profile — what `GAF=1` unlocks and how to use it.

**Local file:** lua/gaf/init.lua, init.lua
**Tags:** gaf freelancer overview profile env-flag

## Scope

The GAF profile is an opt-in env-flag-gated set of Freelancer-specific tooling layered on top of the base Neovim config. It adds the `fl-gaf` PHP monorepo test infra, xdebug remote debugging, Phabricator URL handling, custom neotest adapters (UI tests, profile), basedpyright extra paths, and PHP linting/formatting. Every GAF feature lives under `lua/gaf/` and is gated on `vim.g.gaf` so non-Freelancer use of the config is unaffected.

## How it loads

`init.lua` reads `vim.env.GAF` once on startup:

```lua
vim.g.gaf = vim.env.GAF == "1"
...
require("gaf").setup()
```

`gaf.init.setup()` is the single entry point — it short-circuits when `vim.g.gaf` is false. Currently it only wires xdebug (the other gaf modules are loaded directly from plugin specs via `if vim.g.gaf then require("gaf.X").Y() end` one-liners).

Enable with `GAF=1 nvim`, or alias `alias gnvim='GAF=1 nvim'`.

## Public API

- `require("gaf").setup()` — gated bootstrap; only the xdebug helpers run unconditionally
- All other gaf modules expose their own surfaces — see linked docs below

## Keymaps / Commands

Provided by sub-modules — these are the GAF-gated additions on top of base keymaps:

| Key/Cmd | Mode | Action | Desc |
|---|---|---|---|
| `:GafXdebug*` | cmd | xdebug.lua | Port-forward, validate, profile snapshot |
| `<leader>dx`/`dX`/`dv`/`dD` | n | dap.lua / xdebug.lua | Start/stop xdebug forward, validate, toggle `GAF_DEBUG=1` |
| `<leader>tx`/`tX` | n | test_infra.lua | `bin/run-tests setup` / `shutdown` |
| `<leader>tp`/`tP` | n | neotest-profile.lua | Run/replay with `XDEBUG_MODE=profile` |
| `<leader>tm`/`tw` | n | test.lua | UI test mobile / watch flags |
| `gx` on `D####`/`T####` | n | keymaps.lua | Open Phabricator URL |
| `<leader>r*` / `:Redash*` | n, cmd | redash.nvim ([prod-redash](prod-redash.md)) | Run SQL via Redash HTTP API — scratch, run, schema sidebar, cancel |

## Workflow examples

```sh
# Daily flow — Freelancer dev
GAF=1 nvim webapp/src/...
# Inside nvim:
#   <leader>tx          -- bring up docker test silo
#   <leader>tr          -- run nearest PHPUnit test
#   <leader>dx          -- start xdebug port-forward
#   <leader>db          -- toggle breakpoint, hit endpoint, debug
#   gx on "T123456"     -- open Phabricator task in browser
```

## Links

- [gaf-readme](gaf-readme.md) — workflow cheatsheet
- [gaf-paths](gaf-paths.md) — constants (devbox, fl-gaf root)
- [gaf-keymaps](gaf-keymaps.md) — Phabricator gx opener
- [gaf-lsp](gaf-lsp.md) — PHP intelephense + basedpyright overrides
- [gaf-dap](gaf-dap.md) — PHP xdebug DAP config
- [gaf-test-infra](gaf-test-infra.md) — `bin/run-tests setup/shutdown`
- [gaf-test](gaf-test.md) — neotest extension for fl-gaf
- [gaf-ui-test](gaf-ui-test.md) — UI test overseer templates
- [gaf-neotest-profile](gaf-neotest-profile.md) — xdebug profile capture
- [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md) — yarn ui:* adapter

## Notes

- `vim.g.gaf` is **recomputed on every nvim start** — no state survives.
- Removing the profile: delete `lua/gaf/` + grep `vim.g.gaf` across `lua/plugins/`.
- Devbox hostname is hard-coded to `rtanjaya` in `lua/gaf/paths.lua` — see [gaf-paths](gaf-paths.md).
- Phabricator URL base: `https://phabricator.tools.flnltd.com/`.
