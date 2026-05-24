# gaf-neotest-profile
> Run a PHP test under xdebug profile mode via neotest.

**Local spec:** lua/gaf/neotest-profile.lua:1-43
**Tags:** gaf xdebug profile php neotest

## Scope
Triggers a neotest run with `XDEBUG_MODE=profile` and `NEOTEST_PROFILE=1` set. `bin/gaf-php` reacts to `XDEBUG_MODE=profile` for unit/script runs; `scripts/neotest-run-tests.sh` reacts to `NEOTEST_PROFILE=1` by appending `--profile` to `bin/run-tests` (so functional tests profile correctly inside Docker). After the run, the user uses `:GafXdebugProfileList` / `:Download` / `:Open` to fetch and open the cachegrind file.

## Public API
- `M.run(file)` — guards on PHP project, records `last = { file = file }`, sets env and calls `neotest.run.run({ file, env = env })`.
- `M.run_current()` — `M.run(vim.fn.expand("%:p"))`.
- `M.run_last()` — replays last profile run, warns if none.

PHP-project detection: filetype `php` OR an upward `bin/run-tests` or `composer.json` from the file's directory.

## Keymaps
None bound here. Consumers:
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tp` | n (PHP) | `M.run_current` | Profile file tests TIME |
| `<leader>tP` | n (global, GAF) | `M.run_last` | Profile last test |

## GAF integration
This is the PHP equivalent of `config.neotest-profile-ts` / `-ruby`. Output is xdebug cachegrind (binary), not human-readable — `:GafXdebugProfileList` discovers files on the devbox/local FS, `:Download` pulls them to `~/.cache/xdebug-profiles/`, `:Open` launches the configured viewer (qcachegrind/kcachegrind/webgrind).

Memory profiling is not supported here — see [gaf-test](gaf-test.md) notes.

## Links
- Related: [gaf-test](gaf-test.md), [config-neotest-profile-ts](config-neotest-profile-ts.md), [config-neotest-profile-ruby](config-neotest-profile-ruby.md)

## Notes
- Env vars are passed via neotest's `env` arg — they reach the phpunit subprocess but NOT any nested shell expansions inside `bin/run-tests`. The wrapper script must explicitly read `NEOTEST_PROFILE`/`XDEBUG_MODE` and forward to the container.
- The follow-up notify message is informational only; nothing waits on the run to finish before printing it.
- `last` is module-local — not persisted across `:source` / restart.
