# gaf-readme
> Freelancer-specific workflow cheatsheet distilled from the main README.

**Local file:** README.md (sections "GAF Profile", "Testing", "Debugging")
**Tags:** gaf freelancer workflow cheatsheet phpunit xdebug neotest fl-gaf

## Scope

Quick-reference for daily Freelancer workflows under `GAF=1 nvim`. Covers enabling the profile, running PHPUnit through `bin/run-tests`, the xdebug profile flow, and running webapp UI specs. For exhaustive feature breakdowns see the individual `gaf-*.md` docs.

## How it loads

Enable the profile by setting `GAF=1` in the env before launching nvim. `init.lua` reads it on startup:

```lua
vim.g.gaf = vim.env.GAF == "1"
require("gaf").setup()
```

Recommended alias:

```sh
alias gnvim='GAF=1 nvim'
```

Every GAF feature is gated on `vim.g.gaf`. To temporarily disable, `unset GAF` or use plain `nvim`.

## Public API

This is a workflow doc — see linked modules for actual APIs.

## Keymaps / Commands

PHP / test workflow (GAF-only keys; base test keys in [test-neotest](test-neotest.md)):

| Key/Cmd | Mode | Action | Desc |
|---|---|---|---|
| `<leader>tx` | n | `bin/run-tests setup` | Bring up Docker test silo (writes `.cache/gaf_session_<PID>`) |
| `<leader>tX` | n | `bin/run-tests shutdown` | Tear down silo |
| `<leader>tr` | n | neotest nearest | Routes via `scripts/neotest-run-tests.sh` |
| `<leader>tf` | n | neotest file | Same wrapper |
| `<leader>td` | n | neotest debug | Launches with xdebug attached |
| `<leader>tp` | n | profile run | `XDEBUG_MODE=profile` — capture callgrind |
| `<leader>tP` | n | profile replay | Re-run last profiled test |
| `<leader>tm` / `<leader>tw` | n | ui-test flags | Mobile / watch — active on `ui-tests/*.spec.ts` |
| `<leader>tD` | n | toggle `GAF_DEBUG=1` | Adds `--debug` to neotest invocations |

xdebug + DAP (PHP):

| Key/Cmd | Mode | Action | Desc |
|---|---|---|---|
| `<leader>dx` | n | `:GafXdebugStart` | SSH port-forward `:9003` from devbox |
| `<leader>dX` | n | `:GafXdebugStop` | Kill the forward |
| `<leader>dv` | n | `:GafXdebugValidate` | Sanity-check IDE / DBGp setup |
| `<leader>dc` | n | DAP continue | Picks `Listen for Xdebug (:9003)` config |
| `<leader>db` | n | toggle breakpoint | Persistent across sessions |

Phabricator nav:

| Key | Mode | Action |
|---|---|---|
| `gx` on `D####` | n | Open `https://phabricator.tools.flnltd.com/D####` |
| `gx` on `T####` | n | Open `https://phabricator.tools.flnltd.com/T####` |

## Workflow examples

### Daily PHPUnit run

```sh
GAF=1 nvim src2/Some/HandlerTest.php
```

Inside nvim:

```text
<leader>tx          -- one-time per session: setup
<leader>tr          -- run nearest test
<leader>tf          -- run whole file
<leader>tX          -- shutdown when done (optional, session persists)
```

Tests route through `scripts/neotest-run-tests.sh` → `bin/run-tests <path> --filter <regex> SETUP=false`. Setup must run first or you get "Services are not running".

### xdebug profile capture

```text
<leader>tp          -- runs current test with XDEBUG_MODE=profile, drops callgrind file
<leader>tP          -- replays the same target later (no need to reselect)
```

Open the callgrind dump in KCachegrind / QCachegrind locally.

### Step-debug a remote request

```text
<leader>dx          -- start port-forward 9003 → devbox
<leader>db          -- toggle breakpoint at suspect line
<leader>dc          -- DAP continue (Listen for Xdebug)
# Hit endpoint on devbox; nvim catches the break
<leader>do  / di    -- step over / into
<leader>du          -- open dap-view panel
<leader>dt          -- terminate
<leader>dX          -- stop the forward
```

Path mapping is configured in [gaf-dap](gaf-dap.md) to translate `/mnt/gaf/...` (remote) ↔ `~/freelancer-dev/fl-gaf/...` (local).

### Webapp UI tests

```sh
GAF=1 nvim webapp/projects/<proj>/ui-tests/src/foo.spec.ts
```

```text
<leader>tr          -- runs `yarn ui:<project>` for current spec
<leader>tm          -- mobile viewport
<leader>tw          -- watch mode
<leader>or          -- pick an overseer template (8 ui_test_* variants)
```

## Links

- [gaf-overview](gaf-overview.md) — feature matrix
- [gaf-paths](gaf-paths.md) — constants
- [gaf-keymaps](gaf-keymaps.md) — Phabricator gx
- [gaf-lsp](gaf-lsp.md) — basedpyright extra paths
- [gaf-dap](gaf-dap.md) — xdebug DAP config
- [gaf-test-infra](gaf-test-infra.md) — bin/run-tests setup
- [gaf-test](gaf-test.md) — neotest extension
- [gaf-ui-test](gaf-ui-test.md) — overseer UI templates
- [gaf-neotest-profile](gaf-neotest-profile.md) — profile capture
- [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md) — yarn ui:* adapter
- [docs-keybinds](docs-keybinds.md) — full keymap index

## Notes

- Snacks project picker auto-includes `~/freelancer-dev` under GAF (so `<leader>fp` shows fl-gaf and worktrees).
- `phpcs` lints on save against `fl-gaf/phpcs_gaf.xml`; `php-cs-fixer` uses `fl-gaf/.php-cs-fixer.dist.php`.
- PHP rename uses native `vim.lsp.buf.rename` — see [ftplugin-php](ftplugin-php.md).
- Devbox hostname is hard-coded `rtanjaya` — see [gaf-paths](gaf-paths.md).
- Worktrees (`fl-gaf-worktree/<branch>/`) work transparently because each carries its own `bin/run-tests`.
