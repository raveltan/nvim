# gaf-functional-debug
> How to step-debug GAF PHP functional tests — LOCAL (Docker) vs DEVBOX. Which xdebug config to pick and why.

**Related code:** lua/gaf/dap.lua, lua/gaf/test_infra.lua, scripts/neotest-run-tests.sh, test/docker-compose.yaml
**Tags:** gaf php xdebug dap functional-test breakpoint pathmappings local devbox

## TL;DR — local functional test debug

1. `<leader>tx` — boot Docker test infra (`bin/run-tests setup`).
2. `<leader>dD` — toggle `GAF_DEBUG=1` (wrapper appends `--debug` → xdebug ON in test container).
3. `<leader>db` — set breakpoint on the line.
4. `<leader>dc` — start listener, **pick `PHP: Listen for Xdebug`** (the mason default, NO pathMappings). NOT `Listen for Xdebug (:9003)`.
5. `<leader>tr` (nearest) / `<leader>tf` (file) — run test **normally**. NOT `<leader>td`.
6. Breakpoint hits. Debug.
7. Cleanup: `<leader>dD` (off), `<leader>tX` (shutdown infra), `<leader>dt` (terminate session).

**No port-forward for local.** `<leader>dx` (`:GafXdebugStart`) is DEVBOX-only.

## The two configs — critical

`dap.continue()` shows a picker with two PHP configs. Picking wrong one = breakpoint rejected (solid ● → outlined ○).

| Config | Source | pathMappings | Use for |
|---|---|---|---|
| `PHP: Listen for Xdebug` | mason-nvim-dap default (configurations.lua:161) | **none** | **LOCAL** functional tests |
| `Listen for Xdebug (:9003)` | lua/gaf/dap.lua | `["/mnt/gaf"] = ~/freelancer-dev/fl-gaf` | **DEVBOX** HTTP debug |

Both listen on port 9003. Difference is pathMappings.

### Why the split
- **Local:** test runs in Docker, but xdebug reports paths that match your host checkout 1:1 (no remap needed). The `/mnt/gaf` remap from the gaf config does NOT match → adapter can't bind the breakpoint → **rejected**. Pick the no-pathMappings config.
- **Devbox:** code lives at `/mnt/gaf` on the remote box, your buffer is `~/freelancer-dev/fl-gaf`. Without the remap the paths never match. The gaf config supplies it. Also needs `<leader>dx` port-forward (9003 tunnel to devbox).

## Breakpoint sign meaning
Defs in lua/plugins/dap.lua (config fn):
- `●` `DapBreakpoint` — set, not yet bound.
- `○` `DapBreakpointRejected` — adapter connected but **can't map this file** → wrong pathMappings config. Solid→outlined on session start = picked the wrong listener.
- `▶` `DapStopped` — execution paused here.

## Why NOT `<leader>td` / `<leader>tL` (strategy=dap)
neotest-phpunit's dap strategy (init.lua:37-44) **launches `phpunit_cmd` as a PHP program under DAP**. In GAF, `phpunit_cmd` = `scripts/neotest-run-tests.sh` (bash → Docker). Launching a bash wrapper as `php -dzend_extension=xdebug.so neotest-run-tests.sh` = broken. Strategy=dap does NOT fit the Docker model.

Correct model = **listener**: nvim listens on 9003 (`<leader>dc`), the test runs normally with xdebug enabled in-container (`--debug`), the container connects back. So use `<leader>tr`/`<leader>tf`, never `<leader>td`.

## How the wiring works
- `<leader>dD` → `gaf.test_infra.toggle_debug_flag` sets `vim.env.GAF_DEBUG=1`.
- `scripts/neotest-run-tests.sh` sees `GAF_DEBUG=1` → appends `--debug` to `bin/run-tests` → xdebug enabled in the test container (connects to host `:9003`).
- `test/docker-compose.yaml:22` mounts `./../:/mnt/gaf` — that's the source of the `/mnt/gaf` path (relevant only for the devbox-style mapping).

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| `●` → `○` on session start | wrong listener config (pathMappings mismatch) | local: pick `PHP: Listen for Xdebug`; devbox: pick `Listen for Xdebug (:9003)` |
| `dap: expected not empty table, got nil` | ran `<leader>td`/`<leader>tL` (strategy=dap) | use listener flow + `<leader>tr`/`<leader>tf` |
| breakpoint never hits, no reject | xdebug not on in container | `<leader>dD` BEFORE running; confirm `GAF_DEBUG=1` |
| `Services are not running` | infra not up | `<leader>tx` first |
| listener never connects (devbox) | no port-forward | `<leader>dx` (`:GafXdebugStart`) |

## Links
- [gaf-dap](gaf-dap.md) — the `Listen for Xdebug (:9003)` config + pathMappings.
- [gaf-test-infra](gaf-test-infra.md) — `<leader>tx`/`tX`, `GAF_DEBUG` toggle.
- [gaf-test](gaf-test.md) — neotest phpunit wrapper routing.
- [gaf-xdebug](gaf-xdebug.md) — devbox port-forward + profiling.
- [dap-mason-nvim-dap](dap-mason-nvim-dap.md) — where `PHP: Listen for Xdebug` comes from.
