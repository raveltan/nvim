# gaf-test
> GAF-specific neotest extension: UI-test adapter, phpunit Docker wrapper, infra/profile/debug keys.

**Local spec:** lua/gaf/test.lua:1-63
**Tags:** gaf neotest phpunit ui-tests xdebug profile test-infra

## Scope
Module loaded only when `vim.g.gaf` is true. Patches neotest opts to add the GAF UI-tests adapter and swap the PHPUnit command for the `bin/run-tests` Docker wrapper. Also installs PHP-buffer keymaps for test infra setup/shutdown and xdebug profiling, plus autocmd-driven mobile/watch keys on `ui-tests/src/*.spec.ts` buffers.

## Public API
- `M.extend(opts)` — mutates neotest opts: prepends `neotest-ui-tests` adapter and replaces `neotest-phpunit` with one whose `phpunit_cmd` is `<config>/scripts/neotest-run-tests.sh`.
- `M.attach_keys(buf, filetype)` — for PHP buffers, binds `<leader>tp` (profile), `<leader>tx` (setup infra), `<leader>tX` (shutdown infra).
- `M.global_keys()` — returns a key list with `<leader>tP` (profile last test).
- `M.setup_autocmds()` — `BufEnter` on `*/ui-tests/src/*.spec.ts` binds `<leader>tm` (mobile) and `<leader>tw` (watch) to neotest run with `extra_args`.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tp` | n (PHP) | `gaf.neotest-profile.run_current` | Profile file tests TIME (xdebug profile mode) |
| `<leader>tP` | n (global) | `gaf.neotest-profile.run_last` | Profile last test (xdebug) |
| `<leader>tx` | n (PHP) | `gaf.test_infra.setup_infra` | Setup test infra (bin/run-tests setup) |
| `<leader>tX` | n (PHP) | `gaf.test_infra.shutdown_infra` | Shutdown test infra |
| `<leader>tm` | n (ui-tests) | `neotest.run.run({extra_args={"--mobile"}})` | Run UI test in mobile mode |
| `<leader>tw` | n (ui-tests) | `neotest.run.run({extra_args={"--watch"}})` | Run UI test in watch mode |

## GAF integration
This module IS the GAF integration layer for neotest. Wired from `lua/plugins/test.lua`:
- `init` → `M.setup_autocmds()` (BufEnter handler for UI tests)
- `keys` → `vim.list_extend(keys, M.global_keys())`
- `config` → `M.extend(opts)` before `neotest.setup`
- per-buffer `attach_test_keys` calls `M.attach_keys(buf, ft)`

Memory profiling for local functional tests is NOT supported because `bin/gaf-php` only handles `XDEBUG_MODE=debug|profile|coverage`. For memory profiles, run HTTP endpoints against the rtanjaya devbox via `<leader>Xm` (see xdebug docs).

## Links
- Related: [test-neotest](test-neotest.md), [gaf-test-infra](gaf-test-infra.md), [gaf-neotest-profile](gaf-neotest-profile.md), [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md)

## Notes
- `extend` mutates the adapters table in place — order: ui-tests prepended, phpunit replaced at its original index. ui-tests runs first so it claims `ui-tests/src/*.spec.ts` before jest/vitest can.
- The phpunit replacement re-`require`s `neotest-phpunit` rather than mutating the existing adapter object — necessary because `phpunit_cmd` is captured at construction.
- `<leader>tm` / `<leader>tw` rely on `gaf.neotest-ui-tests` parsing `--mobile`/`--watch` out of `extra_args`.
