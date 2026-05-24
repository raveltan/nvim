# php-debug-coverage
> Debug PHP (xdebug via DAP) + coverage (PHPUnit `--coverage-cobertura`). GAF-gated — requires `GAF=1` env.

**Local specs:** lua/gaf/dap.lua (xdebug config), lua/plugins/dap.lua:143 (gated load), lua/plugins/test.lua (neotest-phpunit + gaf.test.extend), lua/config/neotest-coverage.lua:13-16, lua/plugins/coverage.lua:42-47, scripts/neotest-run-tests.sh
**Tags:** php xdebug gaf phpunit cobertura coverage freelancer devbox docker

## Scope
Two layers — generic PHP DAP wiring (none in non-GAF mode; mason still installs the adapter) and GAF-specific listen-on-9003 config with remote→local path mapping. Coverage routes through `scripts/neotest-run-tests.sh` which runs `phpunit` inside `bin/run-tests` Docker and dumps cobertura XML to a bind-mounted `coverage/` dir.

Without `GAF=1`: PHP debug is **not** configured. Set the env or run `:GafXdebug*` setup first.

## Debug — app / requests
| Action | Key |
|---|---|
| Listen for Xdebug | `<leader>dc` → pick "Listen for Xdebug (:9003)" |
| Start port-forward | `<leader>dx` (`:GafXdebugStart`) |
| Stop port-forward | `<leader>dX` (`:GafXdebugStop`) |
| Validate xdebug setup | `<leader>dv` (`:GafXdebugValidate`) |
| Toggle `--debug` flag | `<leader>dD` |
| Step / terminate / last | `<leader>di / do / dO / dt / dl` |
| UI panel | `<leader>du` |
| BP toggle / cond / clear | `<leader>db` / `<leader>dB` / `<leader>dC` |
| Next / prev BP | `]b` / `[b` |

DAP config (`lua/gaf/dap.lua`):

```lua
dap.configurations.php = { {
  type = "php", request = "launch",
  name = "Listen for Xdebug (:9003)",
  port = 9003,
  pathMappings = { [paths.remote_root] = paths.fl_gaf },
  stopOnEntry = false, log = false,
} }
```

Flow: `<leader>dx` starts SSH port-forward 9003 → devbox. Browser/CLI hit the PHP endpoint; xdebug initiates inbound connection; nvim-dap accepts and pauses at the BP. `paths.remote_root` = devbox path, `paths.fl_gaf` = local checkout — without the mapping, BPs don't match between buffers.

## Debug — tests
GAF replaces neotest-phpunit's `phpunit_cmd` with `scripts/neotest-run-tests.sh` (Docker wrapper) via `gaf.test.extend`.

| Action | Key |
|---|---|
| Debug nearest | `<leader>td` |
| Debug last | `<leader>tL` |
| Run nearest | `<leader>tr` |
| Run file | `<leader>tf` |
| Setup test infra | `<leader>tI` (see [[gaf-test-infra]]) |

Wrapper translates env → flags:
- `XDEBUG_MODE=debug` → start xdebug inside container.
- `NEOTEST_PROFILE=1` → `XDEBUG_MODE=profile`, dumps cachegrind. See [[gaf-neotest-profile]].
- `NEOTEST_COVERAGE=1` → appends `--coverage-cobertura=coverage/cobertura.xml`.
- `GAF_DEBUG=1` → adds `--debug` to phpunit.

## Coverage — wired (GAF)
`<leader>tc` / `<leader>tC` → `lua/config/neotest-coverage.lua:13-16`:

```lua
if ft == "php" then
  coverage_rel = "coverage/cobertura.xml"
  run_env = { NEOTEST_COVERAGE = "1" }
  markers = { "bin/run-tests", "composer.json", ".git" }
```

`scripts/neotest-run-tests.sh` reads `NEOTEST_COVERAGE=1`, `mkdir -p coverage/` on the bind-mounted side, runs phpunit with `--coverage-cobertura=coverage/cobertura.xml`. `nvim-coverage` reads it back via the cobertura parser.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show) |
| `<leader>tV` | `:CoverageSummary` |

## Prereqs
- `GAF=1` in the env when launching nvim — gates `lua/gaf/*` modules.
- Devbox name `rtanjaya` (hard-coded — see auto-memory `gaf_dev_dns`).
- `bin/run-tests` and Docker stack running on devbox (`:GafTestInfraSetup` or `bin/run-tests setup`).
- **lua-xmlreader rock** for the cobertura parser — Homebrew lua@5.5 can't build it; install against lua@5.1 (LuaJIT-ABI-compatible). See [[coverage]] for the exact luarocks command.
- xdebug installed in the Docker PHP image.

## Gotchas
- `setup_php_configuration()` is called in `config = function()` directly — NOT in a `FileType=php` autocmd. Earlier autocmd approach crashed neotest-phpunit's dap strategy with `expected not empty table, got nil` when FileType fired before dap loaded. See lua/gaf/dap.lua:16-20 comment.
- Without xmlreader, `:Coverage` errors `module 'xmlreader' not found`. Re-run the luarocks step in [[coverage]].
- Coverage emits to `coverage/cobertura.xml` **on the bind-mount** — meaning host's `<project>/coverage/cobertura.xml`, not inside the container. The wrapper `mkdir -p`'s the directory to avoid permission issues.
- Port 9003 must be free locally — `:GafXdebugValidate` checks.
- Profile mode (`<leader>tp` analog in GAF) is mutually exclusive with debug — xdebug runs one mode per request.

## Links
- Related: [[gaf-dap]], [[gaf-xdebug]], [[gaf-test]], [[gaf-test-infra]], [[gaf-neotest-profile]], [[dap-nvim-dap]], [[coverage]], [[config-neotest-coverage]], [[workflow-scripts]]
- xdebug: https://xdebug.org/docs/all_settings
- vscode-php-debug: https://github.com/xdebug/vscode-php-debug
- PHPUnit coverage: https://docs.phpunit.de/en/11.0/code-coverage.html
