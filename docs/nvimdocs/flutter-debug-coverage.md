# flutter-debug-coverage
> Debug Dart/Flutter apps + tests + coverage. Fully wired into `<leader>d*` and `<leader>tc`/`<leader>tC`.

**Local specs:** lua/plugins/flutter.lua:36-52, lua/plugins/test.lua:92-95, lua/plugins/coverage.lua, lua/config/neotest-coverage.lua
**Tags:** dart flutter dap debug coverage lcov neotest

## Scope
flutter-tools owns DAP adapter + dartls; neotest-dart drives test discovery/run; nvim-coverage renders gutter signs from `coverage/lcov.info`. Same shape as TS/JS — `flutter test --coverage` emits lcov, dispatcher passes `--coverage` via `extra_args`.

## Debug — running Flutter app
flutter-tools registers a single DAP entry for Dart (`lua/plugins/flutter.lua:39-51`):

```lua
require("dap").configurations.dart = {
  { type = "dart", request = "launch", name = "Launch Flutter",
    dartSdkPath = "dart", flutterSdkPath = "flutter",
    program = "${workspaceFolder}/lib/main.dart",
    cwd = "${workspaceFolder}" },
}
```

`run_via_dap = false`, so `:FlutterRun` uses flutter-tools' built-in runner (streams to dev log tab). Breakpoints still attach because the adapter is registered.

| Step | Keys |
|---|---|
| Launch app | `<leader>Fr` (`:FlutterRun`) |
| Pick device first | `<leader>Fd` (`:FlutterDevices`) or `<leader>Fe` (`:FlutterEmulators`) |
| Set breakpoint | `<leader>db` (persistent-breakpoints — see [[dap-persistent-breakpoints]]) |
| Continue / step | `<leader>dc` / `<leader>di` / `<leader>do` / `<leader>dO` |
| Toggle DAP UI | `<leader>du` |
| Watch expr | `<leader>de` (n/v) |
| Hot reload / restart | `<leader>FR` / `<leader>FM` |
| Dev log tab | `<leader>Fl` |
| Quit | `<leader>Fq` |
| Restart dartls | `<leader>Fc` |

Multiple targets (e.g. `main_dev.dart` vs `main_prod.dart`): edit `register_configurations` to append entries instead of reassigning — see note in [[flutter-tools]].

## Debug — tests
neotest-dart adapter (`lua/plugins/test.lua:92-95`):

```lua
require("neotest-dart")({ command = "flutter", use_lsp = true })
```

| Action | Key |
|---|---|
| Debug nearest test | `<leader>td` |
| Debug last test | `<leader>tL` |
| Run nearest (no dap) | `<leader>tr` |
| Run file | `<leader>tf` |
| Output / panel | `<leader>to` / `<leader>tO` |

`use_lsp = true` leverages dartls for position discovery — falls back to treesitter if dartls hasn't attached yet.

## Coverage — wired
`<leader>tc` / `<leader>tC` → `lua/config/neotest-coverage.lua`:

```lua
elseif ft == "dart" then
  coverage_rel = "coverage/lcov.info"
  run_env = nil
  markers = { "pubspec.yaml", ".git" }
  extra_args = { "--coverage" }
```

Flow: neotest-dart runs `flutter test --coverage <file>` → writes `coverage/lcov.info` → polling timer detects mtime change → `:CoverageLoad` + `:CoverageShow` → gutter signs.

`lua/plugins/coverage.lua` has explicit `dart = { coverage_file = "coverage/lcov.info" }` entry.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show without re-running) |
| `<leader>tV` | `:CoverageSummary` |

Manual: `flutter test --coverage` then `:CoverageLoadLcov coverage/lcov.info` + `:CoverageShow`. lua-xmlreader rock NOT needed (lcov, not cobertura).

## Caveats
- `flutter test --coverage` only instruments code under `lib/`. Tests under `integration_test/` need `flutter test integration_test --coverage` and don't always emit lcov reliably.
- `package:coverage` and `format_coverage` are not used — `flutter test --coverage` invokes them internally.
- If you switch to **fvm**: flutter-tools' DAP runner shells out to `flutter` on `$PATH`. Override `flutter_path` / `flutter_lookup_cmd` in opts or via project exrc — see [[flutter-tools]] "Notes" section.
- `:FlutterRun` does not honor `dap.configurations.dart` — that table is only consulted by `dap.continue()`. To launch the app via DAP from the start, flip `run_via_dap = true` in `lua/plugins/flutter.lua:38`.

## Links
- Related: [[flutter-tools]], [[dap-nvim-dap]], [[test-neotest-adapters]], [[coverage]], [[config-neotest-coverage]]
- neotest-dart: https://github.com/sidlatau/neotest-dart
- Flutter test coverage: https://docs.flutter.dev/cookbook/testing/unit/introduction#generate-a-coverage-report
- nvim-coverage lcov: https://github.com/andythigpen/nvim-coverage
