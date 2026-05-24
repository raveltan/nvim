# python-debug-coverage
> Debug Python (debugpy) + coverage (pytest-cov). All wired into `<leader>d*` and `<leader>tc`/`<leader>tC`.

**Local specs:** lua/plugins/dap.lua:206-256, lua/plugins/test.lua:72-74, lua/plugins/coverage.lua:46-50, lua/config/neotest-coverage.lua:26-30
**Tags:** python debugpy pytest-cov coverage neotest

## Scope
debugpy adapter installed via mason-nvim-dap (`ensure_installed = { "python", ... }`). Four launch configs registered at startup — current file, module prompt, Flask, FastAPI. neotest-python runs pytest; coverage emits `coverage.xml` via `pytest --cov --cov-report=xml`.

## Debug — app / scripts
| Action | Key / Command |
|---|---|
| Pick launch config | `<leader>dc` (then choose from list) |
| Continue / step | `<leader>dc / di / do / dO` |
| Terminate | `<leader>dt` |
| Run last | `<leader>dl` |
| Toggle UI panel | `<leader>du` |
| Toggle BP / cond BP | `<leader>db` / `<leader>dB` |
| Next / prev BP | `]b` / `[b` |
| Watch expr | `<leader>de` (n/v) |

Configurations registered (`lua/plugins/dap.lua:206-256`):
1. **Python: current file** — `program = "${file}"`, `justMyCode = false`.
2. **Python: module** — prompts for module name (`python -m <name>`).
3. **Flask: flask run** — prompts for `FLASK_APP` (default `app.py`), sets `FLASK_DEBUG=1`, runs `flask run --no-debugger --no-reload`.
4. **FastAPI: uvicorn** — prompts for app spec (default `main:app`), `uvicorn <app> --reload --port 8000`.

All use `integratedTerminal` and `justMyCode = false` so steps descend into vendored libs.

## Debug — tests
neotest-python configured with `dap = { justMyCode = false }` (lua/plugins/test.lua:72-74).

| Action | Key |
|---|---|
| Debug nearest | `<leader>td` |
| Debug last | `<leader>tL` |
| Run nearest | `<leader>tr` |
| Run file | `<leader>tf` |
| Run last | `<leader>tl` |
| Output / panel | `<leader>to` / `<leader>tO` |
| Summary | `<leader>ts` |

## Coverage — wired
`<leader>tc` (current file) / `<leader>tC` (rerun last) → `lua/config/neotest-coverage.lua:26-30`:

```lua
elseif ft == "python" then
  coverage_rel = "coverage.xml"
  extra_args = { "--cov", "--cov-report=xml" }
  markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }
```

Flow: neotest runs `pytest --cov --cov-report=xml <file>` → emits `coverage.xml` at project root → polling timer detects mtime change → `:CoverageLoad` + `:CoverageShow` → gutter signs.

| Key | Action |
|---|---|
| `<leader>tc` | Run file with coverage |
| `<leader>tC` | Re-run last with coverage |
| `<leader>tv` | `:Coverage` (load + show without re-running) |
| `<leader>tV` | `:CoverageSummary` |

Manual: `pytest --cov --cov-report=xml` then `:Coverage`.

## Prereqs
- `pip install debugpy pytest pytest-cov` (or pinned via your project's lockfile).
- debugpy installed system-wide-ish by mason; pytest-cov is **not** auto-installed — must be in the project's venv.

## Gotchas
- `justMyCode = false` is debugpy-specific. If you swap neotest-python to `runner = "unittest"` the flag is ignored.
- mason-nvim-dap installs `debugpy` into mason's directory but it relies on your project's Python binary. If you use venvs, set `vim.g.python3_host_prog` or activate the venv before nvim launch.
- `coverage.xml` lives at *project root* (markers above). If nothing renders, check `:!ls coverage.xml` from the project root.
- Polling timeout 10min — long pytest suites should fit.

## Links
- Related: [[dap-nvim-dap]], [[dap-mason-nvim-dap]], [[test-neotest-adapters]], [[coverage]], [[config-neotest-coverage]]
- debugpy: https://github.com/microsoft/debugpy
- pytest-cov: https://pytest-cov.readthedocs.io/
