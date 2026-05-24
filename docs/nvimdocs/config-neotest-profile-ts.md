# config-neotest-profile-ts
> TypeScript/JavaScript jest profiler — `node --cpu-prof` → speedscope.

**Local spec:** lua/config/neotest-profile-ts.lua:1-52
**Tags:** profile typescript javascript jest cpu-prof speedscope

## Scope
Bypasses neotest and shells out directly: `node --cpu-prof --cpu-prof-dir=<root>/tmp/cpu-prof node_modules/.bin/jest --runInBand <file>`. After exit, picks the newest `CPU.*.cpuprofile` and opens it via `npx --yes speedscope`. As fallback, the file can be dragged into Chrome DevTools' Performance tab.

## Public API
- `M.run(file)` — resolves project root via upward `package.json`/`.git`, requires the local `jest` binary, runs the cpu-prof command async via `vim.system`. Registers itself with `config.profile.remember` so `<leader>tP` (global profile-last key) can replay.
- `M.run_current()` — `M.run(vim.fn.expand("%:p"))`.

## Keymaps
Not bound here. Consumed by:
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tp` | n (TS/JS, non-UI) | `M.run_current` | Profile file tests (cpu-prof) |
| `<leader>tP` | n | `config.profile.run_last` | Replay last profile (across languages) |

The buffer-local `<leader>tp` is skipped for `ui-tests/src/*.spec.ts` (those are Karma, not jest — cpu-prof would not apply).

## Our config
- `--runInBand` — single-process so cpu-prof captures the actual jest+test work, not the orchestrator.
- `node_modules/.bin/jest` invoked directly (not `npx jest`) — avoids the npx download/cache check on every run.
- Output dir `tmp/cpu-prof` under project root — gitignored convention matches the GAF webapp `tmp/` layout.
- Speedscope via `npx --yes speedscope` — no global install needed; first run pays the download.

## Links
- Related: [test-neotest](test-neotest.md), [config-neotest-profile-ruby](config-neotest-profile-ruby.md), [gaf-neotest-profile](gaf-neotest-profile.md)
- speedscope: https://github.com/jlfwong/speedscope

## Notes
- The newest-file picker uses `glob`+`table.sort` on `CPU.*.cpuprofile` — node's filename includes a timestamp, so lex-sort is correct.
- `register_template`/coverage-style polling is NOT used — the callback fires from `vim.system` directly on exit.
- If `jest` binary is missing the function errors out before doing any work; install via `yarn install` in the project.
- For ESM projects you may need to prepend `NODE_OPTIONS=--experimental-vm-modules` — not handled here; edit if needed.
