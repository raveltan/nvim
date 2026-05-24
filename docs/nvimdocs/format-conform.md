# format-conform
> Lightweight, async formatter runner driven by filetype tables.

**Repo:** https://github.com/stevearc/conform.nvim
**Local spec:** lua/plugins/formatting.lua:4-27
**Tags:** format formatter prettier stylua ruff php-cs-fixer

## Scope
Runs external formatters per filetype. Our spec is **manual-only** — there is no `format_on_save`. The user triggers formatting via `<leader>cf` (normal & visual). GAF gate adds `php_cs_fixer` for PHP using the Freelancer-specific binary path and config.

## Install spec
```lua
{
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  keys = {
    { "<leader>cf", function() require("conform").format({ async = true }) end,
      mode = { "n", "v" }, desc = "Format file" },
  },
  opts = function() ... end,
}
```

## Common customizations
- `formatters_by_ft` *(table, {})* — map filetype to formatter list. Sequential by default; add `stop_after_first = true` inside the list to stop at the first that succeeds.
- `format_on_save` *(table|function, nil)* — if set, formats on `BufWritePre`. We intentionally omit it.
- `format_after_save` *(table|function, nil)* — async variant; runs after the write completes.
- `formatters` *(table, {})* — override or define formatter specs (command, args, stdin, cwd, env, range_args).
- `default_format_opts` *(table, {})* — passed to every `format()` call (e.g. `{ lsp_format = "fallback" }`).
- `notify_on_error` *(bool, true)* — toast on failure.
- `log_level` *(number, vim.log.levels.ERROR)* — bump for debugging missing binaries.

See `:help conform-options` and `:help conform-formatters`.

## Our config
- `formatters_by_ft`:
  - `lua` → `stylua`
  - `javascript`/`typescript`/`javascriptreact`/`typescriptreact` → `prettierd`, then `prettier`, `stop_after_first = true`
  - `python` → `ruff_organize_imports` then `ruff_format`
  - `dart` → `dart_format`
  - `rust` → `rustfmt`
- GAF only:
  - `formatters_by_ft.php = { "php_cs_fixer" }`
  - `formatters.php_cs_fixer = require("gaf.formatting").php_cs_fixer_formatter()` — uses `~/freelancer-dev/fl-gaf/support/php-cs-fixer/vendor/bin/php-cs-fixer` with the repo's `.php-cs-fixer.dist.php`. See [gaf-formatting](gaf-formatting.md).
- No `format_on_save` — saving never reformats.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>cf` | n, v | `require("conform").format({ async = true })` | Format file |

## GAF integration
When `vim.g.gaf` is true (set via `GAF=1` env, see [nvim_gaf_profile](../../memory/nvim_gaf_profile.md)) the PHP formatter is wired in. The formatter spec itself lives in `lua/gaf/formatting.lua` — see [gaf-formatting](gaf-formatting.md).

## Links
- README: https://github.com/stevearc/conform.nvim
- Help: `:help conform.txt`
- Formatter list: https://github.com/stevearc/conform.nvim/blob/master/doc/formatters.md
- Related: [format-nvim-lint](format-nvim-lint.md), [gaf-formatting](gaf-formatting.md)

## Notes
- `prettierd` is preferred over `prettier` (daemon, faster cold start). Install via mason or system pkg.
- `:ConformInfo` shows which formatters are available for the current buffer and why any are skipped.
- For non-GAF profiles, PHP is **not** formatted by conform — falls back to LSP or nothing.
