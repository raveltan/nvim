# workflow-scripts
> Helper shell scripts that sit between Neovim and external tooling.

**Local spec:** scripts/
**Tags:** workflow scripts neotest phpunit docker gaf test-infra

## Scope
The `scripts/` directory holds shell glue invoked by plugin configs. Currently a single file. Each script is a thin shim that normalizes arguments and shells out to the project's own tooling — we never re-implement the upstream behavior.

## Files

### `scripts/neotest-run-tests.sh`
Wrapper that lets `neotest-phpunit` talk to the GAF `bin/run-tests` Docker entrypoint.

**Invoked by:** `lua/gaf/test.lua` — when `vim.g.gaf` is set, the phpunit adapter is replaced with one whose `phpunit_cmd` is `<nvim-config>/scripts/neotest-run-tests.sh`.

**What it does:**
1. **Find project root** — walks up from the test path until it sees a `bin/run-tests`, falls back to cwd if needed. `realpath`s both so the prefix-strip works for symlinks (e.g. git worktrees).
2. **Strip project-root prefix** — `bin/run-tests` expects a path matching `^test/{unit,functional}/...`, so the absolute path neotest provides gets converted to a relative one.
3. **Normalize `--filter`** — `neotest-phpunit` emits `--filter VALUE` (two args), but `bin/run-tests`' top-level flag loop only collects args matching `--*`. The bare value would be dropped. The wrapper merges into `--filter=VALUE` and re-encodes spaces as `\s` (PHPUnit `--filter` is PCRE so this matches identically).
4. **Redirect `--log-junit`** — Docker only mounts the project dir, so the wrapper points junit output at `.cache/neotest-junit-$$.xml` inside the bind mount and copies the result to the path neotest originally requested on exit.
5. **Coverage opt-in (`NEOTEST_COVERAGE=1`)** — appends `--coverage-cobertura=coverage/cobertura.xml`. Set by `<leader>tc`/`<leader>tC`. Done here rather than via neotest `extra_args` because `neotest-phpunit`'s `build_spec` drops `extra_args`. `bin/gaf-php` auto-flips xdebug into coverage mode when it sees any `--coverage-*` flag.
6. **Debug opt-in (`GAF_DEBUG=1`)** — appends `--debug`. Toggled by `<leader>dD`. Starts xdebug in the test container connecting back to host `:9003` (`<leader>dc` to start the listener first).
7. **Profile opt-in (`NEOTEST_PROFILE=1`)** — appends `--profile`. Set by `<leader>tp`/`<leader>tP`. Enables xdebug profile mode in the test container; `cachegrind.out.*` snapshots end up on the remote `/tmp` and are pulled via `:GafXdebugProfileList`/`Download`/`Open`.
8. **`SETUP=false`** — always. Infrastructure must be brought up explicitly via `<leader>tx` (which calls `bin/run-tests setup`). `bin/run-tests` recovers the worker ID from `.cache/gaf_session_*` and reuses the namespaced silo. Bails out cleanly if no session exists.

**Why a wrapper at all:** keeps Docker infrastructure namespacing (`GAF_TEST_WORKER_ID`), setup, and teardown owned by `bin/run-tests` — we don't reimplement any of it. The wrapper is purely an argument-normalizer + path-mapper.

## Adding a new script
Drop an executable file in `scripts/`, then reference it from a plugin config with `vim.fn.stdpath("config") .. "/scripts/<name>.sh"`. Keep the contract small: read positional + env-var inputs, shell to project tooling, exit with the same code.

## Links
- Related: [gaf-test](gaf-test.md), [test-neotest](test-neotest.md), [coverage](coverage.md), [dap-nvim-dap](dap-nvim-dap.md)

## Notes
- The hardcoded `.cache/neotest-junit-$$.xml` path uses `$$` (PID) for uniqueness — concurrent test runs from the same nvim instance don't collide.
- Devbox `rtanjaya` is the only target — `bin/run-tests` is configured for a single dev's Docker setup, not parameterized.
- If `bin/run-tests` ever drops the `^test/{unit,functional}` prefix requirement, the project-root strip in this wrapper becomes redundant.
