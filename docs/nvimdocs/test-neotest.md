# test-neotest
> Unified test runner with per-language adapters, summary panel, and DAP debugging.

**Repo:** https://github.com/nvim-neotest/neotest
**Local spec:** lua/plugins/test.lua:1-148
**Tags:** neotest test runner dap coverage profile gaf

## Scope
Single test runner UI across PHP, JS/TS, Python, Ruby, Dart, Rust. Provides keymaps for running nearest/file/last tests, a summary panel, output viewer, DAP debug strategy, and integrates with our coverage and profiling helpers. GAF (`vim.g.gaf`) adds a webapp UI-test adapter and docker test-infra commands.

## Install spec
```lua
{
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "olimorris/neotest-phpunit",
    "nvim-neotest/neotest-jest",
    "marilari88/neotest-vitest",
    "nvim-neotest/neotest-python",
    "olimorris/neotest-rspec",
    "zidhuss/neotest-minitest",
    "sidlatau/neotest-dart",
    "rouge8/neotest-rust",
  },
  ft = { "php", "typescript", "javascript", "python", "ruby", "dart", "rust" },
  -- keys/opts/init/config: see local spec
}
```

## Common customizations
- `adapters` *(table, {})* — list of adapter instances, ordered. First matching adapter wins per file.
- `discovery.enabled` *(bool, true)* — auto-discover test files in cwd on startup. Expensive for large repos.
- `status.virtual_text` *(bool, false)* — inline pass/fail markers next to test names.
- `status.signs` *(bool, true)* — gutter signs for pass/fail.
- `output.open_on_run` *(string|bool, "short")* — auto-open output panel: `"short"`, `true`, or `false`.
- `summary.*` — summary panel mappings, position, etc. See `:h neotest.Config`.
- `quickfix.enabled` *(bool, true)* — populate quickfix with failures.

## Our config
- `discovery.enabled = false` — repos are large, manual run-by-file is faster than scanning.
- `status.virtual_text = true` + `signs = true` — both inline and gutter feedback.
- `output.open_on_run = "short"` — short popup auto-opens, full panel via `<leader>tO`.
- Adapters list filters out `ui-tests/src/*.spec.ts` from jest/vitest because those are GAF Karma specs handled by `neotest-ui-tests`.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tr` | n | `neotest.run.run()` | Run nearest test (buffer-local) |
| `<leader>tf` | n | `neotest.run.run(%)` | Run file tests (buffer-local) |
| `<leader>tl` | n | `neotest.run.run_last()` | Run last test |
| `<leader>tL` | n | `run_last({strategy="dap"})` | Debug last test |
| `<leader>td` | n | `run({strategy="dap"})` | Debug nearest test (buffer-local) |
| `<leader>tS` | n | `neotest.run.stop()` | Stop test |
| `<leader>to` | n | `output.open({last_run=true})` | Show last output |
| `<leader>tO` | n | `output_panel.toggle()` | Toggle output panel |
| `<leader>ts` | n | `summary.toggle()` | Toggle summary panel |
| `<leader>tM` | n | `summary.run_marked()` | Run marked tests |
| `<leader>tC` | n | `neotest-coverage.run_last` | Run last test with coverage |
| `<leader>tc` | n | `neotest-coverage.run_current` | Run file tests with coverage (buffer-local) |
| `<leader>tP` | n | `profile.run_last` | Profile last test |
| `<leader>tp` | n | profiler `run_current` | Profile current file (ruby/ts/js, buffer-local) |

## GAF integration
When `vim.g.gaf` is true, `gaf.test.extend(opts)` swaps the phpunit adapter to call `scripts/neotest-run-tests.sh` (Docker wrapper) and prepends `neotest-ui-tests` adapter. Additional buffer keys on PHP buffers: `<leader>tx` setup infra, `<leader>tX` shutdown infra, `<leader>tp` xdebug profile. Global key `<leader>tP` runs `gaf.neotest-profile.run_last`. See [gaf-test](gaf-test.md).

## Links
- README: https://github.com/nvim-neotest/neotest
- Related: [test-neotest-adapters](test-neotest-adapters.md), [gaf-test](gaf-test.md), [config-neotest-coverage](config-neotest-coverage.md), [config-neotest-profile-ts](config-neotest-profile-ts.md), [config-neotest-profile-ruby](config-neotest-profile-ruby.md)

## Notes
- Buffer-local keymaps attach via `FileType` autocmd for the 7 test filetypes; existing buffers are scanned on `config()` so reload works.
- `<leader>tL` / `<leader>td` force-load `dap` before invoking so per-filetype `dap.configurations` are populated (otherwise dap strategy may pick wrong adapter on first run).
- For TS/JS, `<leader>tp` is NOT bound on files matching `ui-tests/src/*.spec.ts` — those go through Karma, not jest, so cpu-prof would not apply.
