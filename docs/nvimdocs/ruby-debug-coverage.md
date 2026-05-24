# ruby-debug-coverage
> Debug Ruby (rdbg) + coverage (SimpleCov). RSpec + Minitest wired.

**Local specs:** lua/plugins/dap.lua:95-99 (nvim-dap-ruby), lua/plugins/test.lua:75-91 (rspec/minitest), lua/config/neotest-coverage.lua:17-20, lua/plugins/coverage.lua (Ruby uses default)
**Tags:** ruby rdbg simplecov rspec minitest rails neotest

## Scope
nvim-dap-ruby registers `dap.adapters.ruby` + a set of `dap.configurations.ruby` (current file, RSpec current file, Rails, attach socket). neotest-rspec / neotest-minitest run tests. Coverage relies on SimpleCov writing `coverage/.resultset.json` — nvim-coverage reads the default path (no override in `coverage.lua`).

## Debug — app / scripts
| Action | Key |
|---|---|
| Pick launch config | `<leader>dc` |
| Step / terminate | `<leader>di / do / dO / dt` |
| Run last | `<leader>dl` |
| Toggle UI | `<leader>du` |
| Toggle BP | `<leader>db` (persistent) |
| Watch | `<leader>de` |

Default `dap.configurations.ruby` entries (from `dap-ruby.setup()`):
- "current file" — `rdbg --open --port ${port} ${file}`.
- "run rspec current_file" — `rdbg ... rspec ${file}`.
- "run rspec" — full suite.
- "debug rails" — `rdbg bin/rails server`.
- "attach rdbg socket" — attach to running rdbg.

To override, reassign `dap.configurations.ruby` after `dap-ruby.setup()`.

## Debug — tests
| Action | Key | Adapter |
|---|---|---|
| Debug nearest | `<leader>td` | neotest-rspec / neotest-minitest |
| Debug last | `<leader>tL` | — |
| Run nearest | `<leader>tr` | — |
| Run file | `<leader>tf` | — |
| Profile file (stackprof) | `<leader>tp` | [[config-neotest-profile-ruby]] |

RSpec runner: prefers `bin/rspec` binstub (Spring/Bootsnap preloaded), falls back to `bundle exec rspec`. Minitest: prefers `bin/rails test`, falls back to `bundle exec ruby -Itest`.

## Coverage — wired
`<leader>tc` / `<leader>tC` → `lua/config/neotest-coverage.lua:17-20`:

```lua
elseif ft == "ruby" then
  coverage_rel = "coverage/.resultset.json"
  run_env = nil          -- assumes SimpleCov.start in spec_helper / test_helper
  markers = { "Gemfile", "Rakefile", ".git" }
```

**Requires SimpleCov already wired in the project.** Typically:

```ruby
# spec/spec_helper.rb (or test/test_helper.rb)
require "simplecov"
SimpleCov.start "rails"   # or :rails / a custom profile
```

Flow: neotest runs RSpec/Minitest → SimpleCov writes `coverage/.resultset.json` → polling timer detects mtime change → `:CoverageLoad` + `:CoverageShow`.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show) |
| `<leader>tV` | `:CoverageSummary` |

Manual: just run tests once SimpleCov is wired, then `:Coverage`.

## Prereqs
- `gem install debug` (rdbg) — on the project Gemfile or system Ruby. Must be on `$PATH` at debug time.
- `gem "simplecov", require: false` in Gemfile (`group :test`) + `require "simplecov"; SimpleCov.start` at the top of the test helper.
- No mason install — rdbg + simplecov are both gems.

## Gotchas
- nvim-dap-ruby is *not* configured via mason — `ensure_installed` in mason-nvim-dap excludes ruby.
- If SimpleCov isn't wired, `coverage/.resultset.json` never updates and the timer eventually times out (10min) with a `Coverage poll timed out` notify.
- Rails projects: SimpleCov must `start` *before* application code loads — put it at the **very top** of `spec_helper.rb` / `test_helper.rb`, above any `require`.
- `bin/rspec` binstub: regenerate with `bundle binstubs rspec-core` if missing — much faster than `bundle exec`.

## Links
- Related: [[dap-nvim-dap]], [[dap-nvim-dap-ruby]], [[test-neotest-adapters]], [[coverage]], [[config-neotest-coverage]], [[config-neotest-profile-ruby]], [[ruby-ror]]
- debug.gem (rdbg): https://github.com/ruby/debug
- SimpleCov: https://github.com/simplecov-ruby/simplecov
