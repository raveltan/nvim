# typescript-debug-coverage
> Debug TS/JS (js-debug-adapter / pwa-node + pwa-chrome) + coverage (jest/vitest lcov).

**Local specs:** lua/plugins/dap.lua:146-168, lua/plugins/test.lua:44-71 (jest/vitest), lua/config/neotest-coverage.lua:21-25
**Tags:** typescript javascript jest vitest pwa-node pwa-chrome lcov neotest

## Scope
js-debug-adapter installed via mason-nvim-dap; the handler registers *two* adapters (`pwa-node`, `pwa-chrome`) sharing the same `dapDebugServer.js`. Two launch configs per ft — Jest current file in `--runInBand` and Chrome attach at `localhost:4200` (ng serve). neotest-jest + neotest-vitest split by `package.json` content; both emit lcov to `coverage/lcov.info` when run with `--coverage`.

## Debug — app / node / browser
| Action | Key |
|---|---|
| Pick launch config | `<leader>dc` |
| Step / terminate | `<leader>di / do / dO / dt` |
| Run last | `<leader>dl` |
| UI panel | `<leader>du` |
| BP toggle / cond / clear | `<leader>db` / `<leader>dB` / `<leader>dC` |
| Next / prev BP | `]b` / `[b` |
| Watch expr | `<leader>de` (n/v) |

Configs (`lua/plugins/dap.lua:146-168`):
1. **Jest: debug current file** — `pwa-node`, runs `node ${workspaceFolder}/node_modules/jest/bin/jest.js --runInBand ${file}`.
2. **Chrome: attach ng serve (localhost:4200)** — `pwa-chrome` with `webRoot = "${workspaceFolder}"`, source maps enabled. Use when `ng serve` is already running.

Both registered for `typescript` and `javascript` filetypes.

## Debug — tests
| Action | Key |
|---|---|
| Debug nearest | `<leader>td` |
| Debug last | `<leader>tL` |
| Run nearest | `<leader>tr` |
| Run file | `<leader>tf` |
| Profile file (cpu-prof) | `<leader>tp` (jest projects, [[config-neotest-profile-ts]]) |

Adapter dispatch (`lua/plugins/test.lua:44-71`):
- neotest-jest matches `*.test.{j,t}sx?` / `*.spec.{j,t}sx?`; excludes `ui-tests/src/*.spec.ts` (Karma).
- neotest-vitest only claims a file if the upward `package.json` mentions `vitest` — keeps jest projects safe.
- Jest before vitest in adapter order — don't reorder without verifying.

## Coverage — wired
`<leader>tc` / `<leader>tC` → `lua/config/neotest-coverage.lua:21-25`:

```lua
elseif ft == "typescript" or ft == "javascript" then
  coverage_rel = "coverage/lcov.info"
  extra_args = { "--coverage" }
  markers = { "package.json", ".git" }
```

Works for both jest (built-in `--coverage` → lcov) and vitest (v8/istanbul reporter writes `coverage/lcov.info` by default). neotest passes `--coverage` to the runner via `extra_args`.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show) |
| `<leader>tV` | `:CoverageSummary` |

Vitest projects: ensure `coverage` block in `vitest.config.ts` sets `reporter: ['text', 'lcov']` (lcov needed for nvim-coverage). Default v8 provider works; istanbul also works.

Manual: `npx jest --coverage` or `npx vitest run --coverage` then `:Coverage`.

## Prereqs
- mason auto-installs `js-debug-adapter`.
- Project must have `jest` or `vitest` in `node_modules`.
- For coverage: jest needs no extra deps; vitest needs `@vitest/coverage-v8` (or `@vitest/coverage-istanbul`).
- Chrome attach: `ng serve` (or any dev server) must already be running on `:4200` with source maps enabled.

## Gotchas
- `dap.configurations.ts/js` get reassigned at config time — adding new entries means appending to the same table in `lua/plugins/dap.lua` (or `vim.list_extend` after require).
- `--runInBand` (jest) is required for breakpoints — without it, workers fork and the debugger can't attach.
- vitest watch mode keeps the process alive; neotest expects exit. Our `extra_args = { "--coverage" }` does not pass `run`, but neotest-vitest's CLI builder uses `vitest run` internally — fine.
- Karma UI tests (`ui-tests/src/*.spec.ts`) are excluded from jest+vitest filters; handled by [[gaf-neotest-ui-tests]] only when `vim.g.gaf`.
- coverage path is **`coverage/lcov.info`** — if your jest config writes elsewhere (e.g. `coverageDirectory`), override in jest.config or symlink.

## Links
- Related: [[dap-nvim-dap]], [[dap-mason-nvim-dap]], [[test-neotest-adapters]], [[coverage]], [[config-neotest-coverage]], [[config-neotest-profile-ts]], [[gaf-neotest-ui-tests]]
- js-debug-adapter: https://github.com/microsoft/vscode-js-debug
- Jest coverage: https://jestjs.io/docs/configuration#coveragereporters-arraystring--string-options
- Vitest coverage: https://vitest.dev/guide/coverage.html
