# gaf-formatting
> Freelancer GAF-specific PHP formatter + linter argument builders.

**Local spec:** lua/gaf/formatting.lua:1-28
**Tags:** gaf php php-cs-fixer phpcs formatter linter

## Scope
Module-only. Provides two helpers that wire Freelancer's `fl-gaf` repo tooling into the generic plugins:
- `php_cs_fixer_formatter()` — a conform.nvim formatter spec pointing at the vendored `php-cs-fixer` binary and the repo's distributed config file.
- `phpcs_args()` — argv for nvim-lint's `phpcs` linter that selects the GAF custom standard and JSON output.

Both are gated by `vim.g.gaf` (set via `GAF=1` env, see [nvim_gaf_profile](../../memory/nvim_gaf_profile.md)) in `lua/plugins/formatting.lua`.

Paths come from `require("gaf.paths")`:
- `paths.fl_gaf` → `~/freelancer-dev/fl-gaf`

## Public API
### `M.php_cs_fixer_formatter() -> table`
Returns a conform formatter table:
```lua
{
  command = "~/freelancer-dev/fl-gaf/support/php-cs-fixer/vendor/bin/php-cs-fixer",
  args = {
    "fix",
    "--config=~/freelancer-dev/fl-gaf/.php-cs-fixer.dist.php",
    "--no-interaction",
    "--quiet",
    "$FILENAME",
  },
  stdin = false,
}
```
- Operates on the file path, not stdin — conform writes a temp file and php-cs-fixer rewrites it in place.
- `--quiet` suppresses progress output so conform's stderr capture stays clean.
- Used in `lua/plugins/formatting.lua:23` as `formatters.php_cs_fixer`. See [format-conform](format-conform.md).

### `M.phpcs_args() -> table`
Returns argv for nvim-lint's `phpcs` linter:
```lua
{
  "-q",
  "--report=json",
  "--standard=~/freelancer-dev/fl-gaf/phpcs_gaf.xml",
  "-",
}
```
- `--report=json` matches nvim-lint's builtin phpcs parser.
- `-` reads from stdin (nvim-lint pipes the buffer).
- The `phpcs` binary itself is set to `./vendor/bin/phpcs` (project-relative) in `lua/plugins/formatting.lua:37`. See [format-nvim-lint](format-nvim-lint.md).

## How it overrides conform for Freelancer PHP
In `formatting.lua`:
```lua
if vim.g.gaf then
  formatters_by_ft.php = { "php_cs_fixer" }
  formatters.php_cs_fixer = require("gaf.formatting").php_cs_fixer_formatter()
end
```
- Without GAF, `php` is absent from `formatters_by_ft` — conform falls back to LSP format (intelephense) or nothing.
- With GAF, the dispatch list is `{ "php_cs_fixer" }` (a single entry, no `stop_after_first` needed) and the spec defined above takes precedence over any builtin `php_cs_fixer` conform ships, ensuring the vendored binary + repo config are used regardless of `$PATH`.
- Manual trigger only — `<leader>cf` formats the buffer; saves do not.

## GAF integration
Entirely a GAF module — `vim.g.gaf` is the gate. Devbox is always `rtanjaya` (hard-coded in `paths.lua`).

## Links
- Related: [format-conform](format-conform.md), [format-nvim-lint](format-nvim-lint.md)
- Memory: [nvim_gaf_profile](../../memory/nvim_gaf_profile.md)
- php-cs-fixer: https://github.com/PHP-CS-Fixer/PHP-CS-Fixer
- PHP_CodeSniffer: https://github.com/PHPCSStandards/PHP_CodeSniffer

## Notes
- `paths.fl_gaf` is `vim.fn.expand("~/freelancer-dev/fl-gaf")` so it works on the local mac, not the devbox itself. Run nvim locally; remote source-mounted via SSHFS/etc.
- If php-cs-fixer is missing run `composer install` inside `fl-gaf/support/php-cs-fixer/`.
- `phpcs_gaf.xml` is the GAF custom sniffer ruleset committed to the fl-gaf repo.
