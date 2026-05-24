# format-nvim-lint
> Async linter runner that pushes diagnostics into Neovim's native vim.diagnostic.

**Repo:** https://github.com/mfussenegger/nvim-lint
**Local spec:** lua/plugins/formatting.lua:29-49
**Tags:** lint diagnostics phpcs

## Scope
Spawns external linters on demand and converts their output into `vim.diagnostic` items. Our spec only enables linting under GAF (PHP via project-local `phpcs`); other profiles register no linters. Trigger is `BufWritePost` so it runs after every save.

## Install spec
```lua
{
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")
    if vim.g.gaf then
      local phpcs = lint.linters.phpcs
      phpcs.cmd = "./vendor/bin/phpcs"
      phpcs.args = require("gaf.formatting").phpcs_args()
      lint.linters_by_ft = { php = { "phpcs" } }
    else
      lint.linters_by_ft = {}
    end
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      group = vim.api.nvim_create_augroup("lint", { clear = true }),
      callback = function() lint.try_lint() end,
    })
  end,
}
```

## Common customizations
- `lint.linters_by_ft` *(table, {})* — filetype → list of linter names.
- `lint.linters.<name>` *(table)* — override or define a linter (`cmd`, `args`, `stdin`, `append_fname`, `stream`, `ignore_exitcode`, `parser`).
- `lint.try_lint(names?, opts?)` — manually run a specific linter; without args runs all configured for the buffer.
- Builtin parsers live in `lint.parser.from_errorformat` and `from_pattern`.

See `:help nvim-lint`.

## Our config
- GAF only:
  - `lint.linters.phpcs.cmd = "./vendor/bin/phpcs"` — uses the project-local binary (devbox or local checkout).
  - `lint.linters.phpcs.args = require("gaf.formatting").phpcs_args()` → `{ "-q", "--report=json", "--standard=<fl-gaf>/phpcs_gaf.xml", "-" }`. See [gaf-formatting](gaf-formatting.md).
  - `lint.linters_by_ft = { php = { "phpcs" } }`
- Non-GAF: `linters_by_ft = {}` — nothing runs, but the autocmd is still installed (a no-op).
- Autocmd: `BufWritePost` in `augroup lint` (cleared each load) → `lint.try_lint()`.

## Keymaps
None — purely save-driven.

## GAF integration
PHP linting only fires when `vim.g.gaf` (set by `GAF=1` env). The phpcs binary path is relative (`./vendor/bin/phpcs`) so the buffer's project root must contain composer-installed phpcs. The custom standard `phpcs_gaf.xml` ships with the fl-gaf repo. See [gaf-formatting](gaf-formatting.md).

## Links
- README: https://github.com/mfussenegger/nvim-lint
- Linter list: https://github.com/mfussenegger/nvim-lint/blob/master/doc/nvim-lint.txt
- Related: [format-conform](format-conform.md), [gaf-formatting](gaf-formatting.md)

## Notes
- `phpcs` is invoked with `-` (stdin) and `--report=json` so nvim-lint's json parser can attach diagnostics correctly.
- To debug, run `:lua require("lint").try_lint()` then `:messages`, or check `:checkhealth lint`.
- If you add a non-GAF linter, attach it inside the `else` branch or restructure the conditional.
