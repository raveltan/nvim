# config-neotest-coverage
> Run a neotest with language-specific coverage env, then load into nvim-coverage.

**Local spec:** lua/config/neotest-coverage.lua
**Tags:** coverage neotest cobertura lcov simplecov llvm-cov nvim-coverage

## Scope
Runs the current file's tests through neotest with env/flags that emit a coverage report file, then polls that file and invokes `:CoverageLoad` + `:CoverageShow` when it updates. Supports PHP, Ruby, TypeScript/JavaScript, Python, Rust, Dart — each with its own root markers, env vars, extra args, and coverage path.

## Public API
- `M.run(file, ft)` — dispatches by filetype, sets env/extra_args, calls `neotest.run.run`, then starts a 1s-interval timer (10min cap) polling the coverage file. On fingerprint change (`mtime.sec:mtime.nsec:size`), loads/shows coverage and stops the timer.
- `M.run_current()` — `M.run(vim.fn.expand("%:p"), vim.bo.filetype)`.
- `M.run_last()` — replays last run; warns if none.

## Per-filetype settings
| ft | Coverage path | Env | Extra args | Markers |
|----|---|---|---|---|
| php | `coverage/cobertura.xml` | `NEOTEST_COVERAGE=1` | — | `bin/run-tests`, `composer.json`, `.git` |
| ruby | `coverage/.resultset.json` | — | — | `Gemfile`, `Rakefile`, `.git` |
| ts/js | `coverage/lcov.info` | — | `--coverage` | `package.json`, `.git` |
| python | `coverage.xml` | — | `--cov --cov-report=xml` | `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `.git` |
| rust | `coverage/lcov.info` | `CARGO_LLVM_COV=1`, `CARGO_LLVM_COV_TARGET_DIR=target/llvm-cov-target`, `LLVM_COV_FLAGS=--lcov --output-path=coverage/lcov.info` | — | `Cargo.toml`, `.git` |
| dart | `coverage/lcov.info` | — | `--coverage` | `pubspec.yaml`, `.git` |

## Keymaps
Not bound here. Consumed by:
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tc` | n (test ft) | `M.run_current` | Run file tests with coverage |
| `<leader>tC` | n | `M.run_last` | Run last test with coverage |

## Our config
- PHP `NEOTEST_COVERAGE=1` — picked up by `scripts/neotest-run-tests.sh` (GAF) to enable xdebug coverage.
- Ruby has no env — assumes `SimpleCov.start` is in `spec_helper.rb`/`test_helper.rb`.
- Rust requires `cargo-llvm-cov` installed; the env triggers llvm-cov-instrumented build via the neotest-rust adapter.
- 10-minute timeout — long enough for full-suite runs on big repos.
- Stat-fingerprint detection (`mtime.sec` + `mtime.nsec` + `size`): avoids needing neotest result callbacks (which don't fire reliably for coverage post-processing). mtime seconds alone missed same-second rewrites, letting the poll run to timeout.

## Links
- Related: [test-neotest](test-neotest.md)
- nvim-coverage: https://github.com/andythigpen/nvim-coverage
- cargo-llvm-cov: https://github.com/taiki-e/cargo-llvm-cov

## Notes
- Polls every 1s — cheap but visible if you `:CoverageShow` manually before the timer fires.
- `prev_fp` fingerprint snapshot is taken BEFORE the run, so even if the file already existed, only a fresh write triggers load.
- Python's `--cov` requires `pytest-cov`; Ruby relies on SimpleCov; nothing here installs these — assumed present in the project.
- `pcall(vim.cmd, ...)` swallows errors if nvim-coverage isn't loaded — coverage just silently doesn't render.
- `last` is module-local; not persisted across restart.
