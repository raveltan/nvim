# test-neotest-adapters
> Per-language neotest adapter configs (PHP, JS/TS, Python, Ruby, Dart, Rust).

**Local spec:** lua/plugins/test.lua:8-15 (deps), lua/plugins/test.lua:41-98 (configs)
**Tags:** neotest adapters phpunit jest vitest python rspec minitest dart rust

## Scope
Eight language adapters wired into the neotest core. Each is invoked with a small config object (commands, filters) tailored to GAF and other multi-repo conventions. Adapter order matters — first match wins, so jest is listed before vitest and both filter out the GAF UI-test spec path.

## Install spec
See [test-neotest](test-neotest.md) `dependencies`. Each adapter is configured inside `opts.adapters` (lua/plugins/test.lua:40-99):

```lua
require("neotest-phpunit")({ phpunit_cmd = "vendor/bin/phpunit" })
require("neotest-jest")({ jestCommand = "npx jest", isTestFile = fn })
require("neotest-vitest")({ filter_dir = fn, is_test_file = fn })
require("neotest-python")({ dap = { justMyCode = false } })
require("neotest-rspec")({ rspec_cmd = fn, filter_dirs = {...} })
require("neotest-minitest")({ test_cmd = fn })
require("neotest-dart")({ command = "flutter", use_lsp = true })
require("neotest-rust")({ args = { "--no-capture" } })
```

## Adapters

### neotest-phpunit
PHP. Runs `vendor/bin/phpunit` by default. In GAF, swapped to `scripts/neotest-run-tests.sh` (Docker wrapper) by `gaf.test.extend`.
Repo: https://github.com/olimorris/neotest-phpunit

### neotest-jest
JS/TS Jest. Command `npx jest`. `isTestFile` matches `*.test.{j,t}sx?` / `*.spec.{j,t}sx?` and excludes `ui-tests/src/*.spec.ts` (those are Karma).
Repo: https://github.com/nvim-neotest/neotest-jest

### neotest-vitest
JS/TS Vitest. `filter_dir` skips `node_modules` and `ui-tests`. `is_test_file` only matches when the upward-found `package.json` mentions `vitest` — so jest projects are not misdetected.
Repo: https://github.com/marilari88/neotest-vitest

### neotest-python
Python (pytest/unittest). `dap.justMyCode = false` so debugpy steps into vendored libs.
Repo: https://github.com/nvim-neotest/neotest-python

### neotest-rspec
Ruby RSpec. `rspec_cmd` prefers `bin/rspec` (binstub) and falls back to `bundle exec rspec`. `filter_dirs` excludes `.git node_modules vendor tmp coverage log`.
Repo: https://github.com/olimorris/neotest-rspec

### neotest-minitest
Ruby Minitest. `test_cmd` prefers `bin/rails test` if Rails binstub exists, else `bundle exec ruby -Itest`.
Repo: https://github.com/zidhuss/neotest-minitest

### neotest-dart
Dart/Flutter. `command = "flutter"`, `use_lsp = true` to leverage flutter-tools LSP for position discovery.
Repo: https://github.com/sidlatau/neotest-dart

### neotest-rust
Rust. `args = { "--no-capture" }` so println output reaches the panel. Coverage path uses `cargo-llvm-cov` env (see neotest-coverage).
Repo: https://github.com/rouge8/neotest-rust

## Our config
- jest before vitest — most webapp packages still use jest; vitest's per-package `package.json` check resolves the rest.
- jest + vitest both exclude `ui-tests/src/*.spec.ts` — handled by `neotest-ui-tests` Karma adapter (GAF only).
- rspec uses `bin/rspec` binstub when present — preloads Spring/Bootsnap and is much faster than `bundle exec`.
- minitest follows the same binstub-first pattern via `bin/rails test`.

## GAF integration
In `gaf.test.extend`, `neotest-phpunit` is replaced with a wrapper that points `phpunit_cmd` at `scripts/neotest-run-tests.sh`. The wrapper script handles `bin/run-tests` (Docker), per-session worker IDs, and translates `XDEBUG_MODE`/`NEOTEST_PROFILE`/`NEOTEST_COVERAGE`/`GAF_DEBUG` env into CLI flags.

## Links
- Related: [test-neotest](test-neotest.md), [gaf-test](gaf-test.md), [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md)

## Notes
- Do NOT reorder jest/vitest without verifying — vitest's package.json check is the only thing keeping it from claiming jest files.
- `dap.justMyCode = false` (python) is a debugpy-specific option; if you swap to neotest-python's `runner = "unittest"` it is ignored.
