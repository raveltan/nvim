# coverage
> Gutter signs + summary panel for line coverage across PHP, Ruby, Python, Rust.

**Repo:** https://github.com/andythigpen/nvim-coverage
**Local spec:** lua/plugins/coverage.lua:1-58
**Tags:** coverage cobertura simplecov lcov phpunit pytest cargo-llvm-cov

## Scope
Lazy-loaded on `Coverage*` commands and `<leader>tv`/`<leader>tV`. Parses coverage reports written by each language's standard tool, renders gutter signs for covered/uncovered/partial lines, and a buffer-list summary with totals. Reports the plugin reads:

| Language | File | Generator |
|----------|------|-----------|
| PHP | `coverage/cobertura.xml` | PHPUnit `--coverage-cobertura=coverage/cobertura.xml` (auto-injected by `scripts/neotest-run-tests.sh` when `NEOTEST_COVERAGE=1`) |
| Ruby | `coverage/.resultset.json` | SimpleCov default output |
| Python | `coverage.xml` | `pytest --cov --cov-report=xml` |
| Rust | `coverage/lcov.info` | `cargo llvm-cov --lcov --output-path coverage/lcov.info` |

## Install spec
```lua
{
  "andythigpen/nvim-coverage",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "Coverage", "CoverageLoad", "CoverageLoadLcov", "CoverageShow", "CoverageHide",
          "CoverageToggle", "CoverageClear", "CoverageSummary" },
  init = function()                                       -- prepend ~/.luarocks paths so xmlreader is findable
    local home = os.getenv("HOME") or ""
    local rocks_lib   = home .. "/.luarocks/lib/lua/5.1/?.so"
    local rocks_share = home .. "/.luarocks/share/lua/5.1/?.lua"
    if not package.cpath:find(rocks_lib,   1, true) then package.cpath = package.cpath .. ";" .. rocks_lib   end
    if not package.path :find(rocks_share, 1, true) then package.path  = package.path  .. ";" .. rocks_share end
  end,
  opts = {
    auto_reload = true,
    lang = {
      php    = { coverage_file = "coverage/cobertura.xml" },
      python = { coverage_file = "coverage.xml" },
      rust   = { coverage_file = "coverage/lcov.info" },
    },
  },
}
```

## lua-xmlreader install note (PHP cobertura only)
The Cobertura parser depends on the `lua-xmlreader` rock. Homebrew's `lua` is currently 5.5, which removed `luaL_checkint` / `luaL_register`, so the rock won't build against it. Install against Lua 5.1 — LuaJIT (Neovim's interpreter) is 5.1-ABI compatible:

```sh
brew install lua@5.1
luarocks --lua-version=5.1 --lua-dir="$(brew --prefix lua@5.1)" \
    install --local lua-xmlreader
```

The `init` function then prepends `~/.luarocks/{lib,share}/lua/5.1/` to LuaJIT's `package.cpath`/`package.path` so `require("xmlreader")` resolves. Without those entries Neovim's LuaJIT only searches its bundled paths and the rock is invisible.

## Common customizations
- `auto_reload` *(bool, false)* — re-read the coverage file when it changes on disk. We enable so `:CoverageShow` stays fresh while re-running tests.
- `lang.<lang>.coverage_file` *(string)* — path (relative to cwd) where the parser looks. Defaults are typically right; we override PHP/Python/Rust to match our tooling.
- `lang.<lang>.parser` *(string)* — override the parser name. Rarely needed.
- `signs` *(table)* — customize covered/uncovered/partial gutter symbols and highlight groups.
- `summary` *(table)* — buffer-list panel options (`position`, `width`, `min_coverage`).
- `highlights` *(table)* — `CoverageCovered` / `CoverageUncovered` / `CoveragePartial` highlight links.
- `load_coverage_cb` *(fn(ftype))* — callback after a coverage file is loaded.

## Our config
- `auto_reload = true` so re-runs refresh without manual `:CoverageLoad`.
- PHP: `coverage/cobertura.xml` — matches the path the neotest wrapper writes when `NEOTEST_COVERAGE=1`.
- Python: `coverage.xml` — convention for `pytest-cov --cov-report=xml`.
- Rust: `coverage/lcov.info` — matches `cargo llvm-cov --lcov --output-path coverage/lcov.info`.
- Ruby: default left alone (`coverage/.resultset.json` from SimpleCov).

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tv` | n | `:Coverage` | Load + show signs |
| `<leader>tV` | n | `:CoverageSummary` | Open summary panel (per-file totals) |

## Links
- README: https://github.com/andythigpen/nvim-coverage
- lua-xmlreader: https://luarocks.org/modules/luarocks/lua-xmlreader
- Cargo llvm-cov: https://github.com/taiki-e/cargo-llvm-cov
- SimpleCov: https://github.com/simplecov-ruby/simplecov

## Notes
- `<leader>tc` (run current file with coverage) and `<leader>tC` (rerun last) live in [test-neotest](test-neotest.md) — neotest sets `NEOTEST_COVERAGE=1` and the wrapper script appends `--coverage-cobertura=coverage/cobertura.xml` to phpunit. `<leader>tv` after that lights the gutters up.
- For the Docker GAF test infrastructure, the wrapper script auto-`mkdir -p coverage/` inside the project root so `coverage/cobertura.xml` ends up on the bind-mounted side, then nvim-coverage reads it from there. See [gaf-test](gaf-test.md) and [workflow-scripts](workflow-scripts.md).
- If `:Coverage` errors with `module 'xmlreader' not found`, redo the luarocks step above and restart nvim.
