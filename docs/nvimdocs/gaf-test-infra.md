# gaf-test-infra
> Setup/shutdown helpers for fl-gaf Docker test infrastructure via bin/run-tests.

**Local spec:** lua/gaf/test_infra.lua:1-99
**Tags:** gaf docker bin-run-tests test-infra session

## Scope
Wraps `bin/run-tests setup` / `bin/run-tests shutdown` as async jobs from Neovim. Shutdown reads cached worker IDs from `.cache/gaf_session_*` so per-session Docker stacks tear down cleanly, even when multiple Neovim/test sessions share the repo. Also exposes a `GAF_DEBUG` toggle.

## Public API
- `M.setup_infra()` — locates upward `bin/run-tests`, runs `bin/run-tests setup` as a job, notifies on success/failure.
- `M.shutdown_infra()` — scans `<root>/.cache/gaf_session_*` for worker IDs. If none, runs a single `bin/run-tests shutdown`. Otherwise runs one shutdown per worker with `GAF_TEST_WORKER_ID=<id>` env, aggregating success/failure.
- `M.toggle_debug_flag()` — flips `vim.g.gaf_test_debug` and sets/unsets `GAF_DEBUG=1` env. The `scripts/neotest-run-tests.sh` wrapper appends `--debug` to `bin/run-tests` when this env is set.

## Keymaps
None bound here. Consumed by:
- `gaf.test.attach_keys` → `<leader>tx` (setup), `<leader>tX` (shutdown) on PHP buffers
- xdebug / gaf-debug modules → `<leader>dD` toggles `toggle_debug_flag`

## GAF integration
Core piece of the GAF test workflow:
1. `<leader>tx` boots Docker test stack (`mysql_test`, redis_test, etc.) once per workspace.
2. Neotest runs route through `scripts/neotest-run-tests.sh` which writes a per-session worker ID into `.cache/gaf_session_<pid>`.
3. `<leader>tX` reads every cached ID and shuts down each session, ensuring no orphan containers.

`find_root` walks up from cwd looking for an executable `bin/run-tests`; matches fl-gaf repo layout. Devbox is always `rtanjaya` but this module operates locally.

## Links
- Related: [gaf-test](gaf-test.md)

## Notes
- Uses `vim.fn.jobstart` (not `vim.system`) — predates the unified API but works fine.
- If `.cache/gaf_session_*` is empty, a generic shutdown runs (covers fresh clones / never-ran-tests state).
- `failed` list is the list of worker IDs whose shutdown exited non-zero; the error notification names them so you can `docker ps` and clean up by hand.
- `toggle_debug_flag` mutates `vim.env.GAF_DEBUG` — this propagates to child jobs but does NOT survive a shell `:!` unless re-exported.
