# config-neotest-profile-ruby
> Ruby test profiler — stackprof → d3-flamegraph HTML.

**Local spec:** lua/config/neotest-profile-ruby.lua:1-66
**Tags:** profile ruby stackprof flamegraph rspec minitest

## Scope
Runs the current test file under `bundle exec stackprof run --raw` (rspec or rails-test or plain ruby, auto-detected), then converts the dump to a self-contained d3-flamegraph HTML via `stackprof --d3-flamegraph` and opens it with `open`. Requires `gem "stackprof"` in the target project's Gemfile.

## Public API
- `M.run(file)` — resolves root via upward `Gemfile`/`.git`, picks runner via `detect_runner`, writes `tmp/stackprof-<ts>.dump` and `tmp/stackprof-<ts>.html`. Registers with `config.profile.remember` for replay.
- `M.run_current()` — `M.run(vim.fn.expand("%:p"))`.

Runner detection:
- `*_spec.rb` → `bin/rspec` if executable, else `bundle exec rspec`
- otherwise → `bin/rails test` if `bin/rails` exists, else `bundle exec ruby -Itest`

## Keymaps
Not bound here. Consumed by:
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tp` | n (Ruby) | `M.run_current` | Profile file tests (stackprof) |
| `<leader>tP` | n | `config.profile.run_last` | Replay last profile |

## Our config
- `--raw` — full stack samples (needed for accurate flamegraph; the default mode aggregates).
- `--d3-flamegraph` — produces a single-file HTML you can email, instead of needing stackprof-webnav running.
- Output to `tmp/` — gitignored convention.
- Uses `bin/rspec` / `bin/rails` binstubs when present — preloads Spring/Bootsnap, much faster cold start.

## Links
- Related: [test-neotest](test-neotest.md), [config-neotest-profile-ts](config-neotest-profile-ts.md), [gaf-neotest-profile](gaf-neotest-profile.md)
- stackprof: https://github.com/tmm1/stackprof

## Notes
- Two `vim.system` calls chained inside `schedule_wrap`: first runs the test, second post-processes. Errors in either notify and abort cleanly.
- `open` is macOS-specific. Linux users will need `xdg-open` (edit the `jobstart` call).
- HTML file is written via Lua `io.open` — captures `flame.stdout` directly so we don't need a `--output` flag.
- The dump is NOT deleted — useful for re-rendering or feeding into `stackprof --text`/`--graphviz`. Clean `tmp/stackprof-*` periodically.
