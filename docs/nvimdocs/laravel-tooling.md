# laravel-tooling
> Pint, phpstan/larastan, Pest, Xdebug, IDE helper, Livewire navigation.

**Local spec:** lua/artisan/ (init, formatting, lint, dap, test, ide_helper, livewire)
**Tags:** laravel pint phpstan larastan pest xdebug ide-helper livewire volt neotest

## Detection model
`lua/gaf/` is one checkout behind an env flag, so it decides everything at startup. Laravel is *whatever project this buffer belongs to* — several can be open at once, or none — so `lua/artisan/init.lua` resolves the project from the **buffer's** path on every call and returns `nil` when there isn't one. That `nil` is also what keeps all of this inert inside fl-gaf (no `artisan` file).

The module is `artisan`, **not** `laravel`: a `lua/laravel/` here would shadow laravel.nvim's own entry point (the config's `lua/` is at the head of the runtimepath), silently preventing the plugin from ever booting.

```lua
local artisan = require("artisan")
artisan.root(bufnr_or_dir)  -- nearest ancestor containing `artisan`, or nil
artisan.is_laravel(...)
artisan.env(root)           -- "sail" | "docker" | "local"
artisan.bin(name, root)     -- vendor/bin → node_modules/.bin → mason → $PATH, absolute
artisan.artisan_cmd(root)
```

`env()` keys on a **compose file**, not on `vendor/bin/sail`: `laravel/sail` is a dependency of the default skeleton, so the binary exists in every project whether or not it was ever installed. Keying on the binary made plain Herd projects report `sail` and route artisan through a container that wasn't there.

Formatters and static analysers deliberately run on the **host** even under sail — pint and phpstan are plain PHP, and a `docker exec` per save would stall every write and fail outright with the containers down.

`:LaravelRoot` reports what was detected. `:LaravelArtisan <cmd>` runs artisan in a Snacks terminal.

## Formatting — Pint
`php` → `{ "pint", "php_cs_fixer", stop_after_first = true }`, `blade` → `blade-formatter` (lua/artisan/formatting.lua).

Every entry is condition-guarded on the project shipping the tool. Pint *is* php-cs-fixer with Laravel's ruleset baked in, so a globally-installed `pint` must never restyle an unrelated PHP repo; `php_cs_fixer` additionally requires a `.php-cs-fixer*` config, since with none it rewrites to its own defaults. When nothing matches, conform's `lsp_format = "fallback"` lets intelephense format.

`pint`, `blade-formatter` and `phpstan` are in mason's `ensure_installed` as global fallbacks for a project whose dependencies aren't installed yet; project binaries always win. Mason's `pint` needs PHP ≥ 8.2.

## Static analysis — phpstan / larastan
Runs on `BufWritePost`, dispatched per buffer from lua/plugins/formatting.lua rather than declared in `linters_by_ft` (eligibility is per project; `linters_by_ft` is global). Three guards must all pass:

1. the buffer sits under an `artisan` root
2. `vendor/bin/phpstan` (or mason's) exists
3. a `phpstan.neon` / `phpstan.neon.dist` / `phpstan.dist.neon` exists

Args: `analyse --error-format=json --no-progress --memory-limit=2G -c <config>`. The memory limit is not optional — bootstrapping larastan loads the whole framework and dies on the default 128M.

**The process environment is scrubbed first.** PHPStan 2.x sniffs `CLAUDECODE`, `AI_AGENT`, `CURSOR_AGENT`, `GEMINI_CLI` and friends (its `AiAgentDetector::ENV_VARS`) and switches to an agent-shaped output that *overrides* `--error-format=json`. Neovim launched from an agent-managed terminal inherits the marker and gets **zero diagnostics on every save**. `clean_env()` strips them for the phpstan process only.

**A missing `includes:` target is caught before spawning.** phpstan exits 1 while writing nothing to stdout *or* stderr in that case, so there is no output to parse and no stream to watch — the run is indistinguishable from a clean file. The config is checked up front and reported once instead.

`:LaravelPhpstan [level]` runs the whole project into the quickfix list.

Two overrides of the nvim-lint builtin (lua/artisan/lint.lua):
- **cmd** — the builtin resolves `vendor/bin/phpstan` with `fnamemodify(':p')`, i.e. relative to **cwd**; ours resolves from the buffer's root. Same failure already documented for phpcs.
- **parser** — the builtin calls `vim.json.decode` unguarded, so a PHP fatal while bootstrapping throws inside the lint callback on every save. Ours reports each distinct failure once.

> `args` must stay a **list**. nvim-lint runs `vim.tbl_map` over it, so a function in its place is dropped and phpstan runs with no arguments — which looks exactly like "no errors". Only the elements may be functions.

## Testing — Pest / PHPUnit
Pest wraps PHPUnit but is not compatible with the phpunit adapter (different `--filter` syntax, different result file), and `neotest-pest`'s `is_test_file` claims any `*Test.php` — so the two are **mutually exclusive**, decided once at neotest setup (lua/plugins/test.lua):

Both adapters are registered and gated **per file** — pest claims a test file whose project has `tests/Pest.php`, phpunit claims everything else (including plain non-Laravel PHP). Deciding once at setup used cwd, so `nvim ~/project/tests/FooTest.php` from another directory registered phpunit rooted at the wrong place and the run died with `E475: 'vendor/bin/phpunit' is not executable`.

`pest_cmd` resolves to an absolute path for the same reason: the adapter's default is relative and it sets no `cwd` on the spec.

The usual `<leader>t*` maps apply unchanged. Parallel runs are opt-in per project: `vim.g.laravel_pest_parallel = 4`.

**Pest snippets** live in `snippets/pest/` and are registered under a synthetic `pest` filetype. A custom LuaSnip `ft_func` (lua/plugins/lsp.lua) adds that filetype only in php buffers whose project is Pest-driven, so `it`/`test`/`describe` never appear in fl-gaf's PHPUnit buffers. Loading them on demand instead would leak: LuaSnip's registry is global, so once loaded they would stay in every php buffer for the rest of the session. `it test describe beforeEach afterEach beforeAll uses expect expectc itwith dataset throws todo skip group covers phttp pacting pdb prefresh pmock pspy`.

## Debugging — Xdebug
`dap.configurations.php` (lua/artisan/dap.lua). The adapter itself is already registered by mason-nvim-dap (`php` is in its `ensure_installed`); only configurations were missing outside GAF, which is why `<leader>dc` on a php buffer used to offer nothing.

| Name | Notes |
|---|---|
| `Xdebug: listen (:9003)` | **No** `pathMappings` — Herd, Valet and `artisan serve` report the paths the editor sees; a mapping here silently unbinds every breakpoint |
| `Xdebug: listen (:9003) — Sail/Docker` | maps `/var/www/html` → `${workspaceFolder}` |
| `Xdebug: launch current file` | forces `-dxdebug.mode=debug -dxdebug.start_with_request=yes` on the command line, so php.ini can stay clean |
| `Xdebug: launch artisan command` | prompts for the subcommand |

All four set `ignore = { "**/vendor/**/*.php" }` (keeps the debugger out of Illuminate internals) and raise `max_children`/`max_data`/`max_depth`, whose defaults truncate Eloquent models into uselessness.

| Key | Action |
|---|---|
| `<leader>dp` | Start the listener that matches this project's environment (skips the picker) |
| `<leader>dP` | Pick a php configuration |

GAF and Laravel both own `dap.configurations.php` outright, so exactly one of them runs.

## intelephense + IDE helper
Without generated helper files intelephense sees `Route::get()` as an undefined static method — the real signature only exists at runtime via `__callStatic`. `:LaravelIdeHelper [facades|models|meta]` runs the generators in order and restarts intelephense (it has no reindex request):

| Step | Writes |
|---|---|
| `ide-helper:generate` | `_ide_helper.php` — facade signatures |
| `ide-helper:models -M -n` | `_ide_helper_models.php` + one `@mixin` line per model |
| `ide-helper:meta` | `.phpstorm.meta.php` — container binding return types |

`-M` writes only the mixin docblock, so model files aren't rewritten; `-n` is required or the command blocks on a prompt forever. If `barryvdh/laravel-ide-helper` is missing it offers to `composer require --dev` it first (it edits composer.json, so it asks).

lua/artisan/lsp.lua adds Laravel deltas to intelephense: the framework's extension `stubs` (redis, memcached, imagick, pcov, xdebug, swoole, mongodb, …, on top of the full default list, which the setting *replaces* rather than extends) and excludes for `bootstrap/cache`, `public/build`, `public/hot`, `.phpunit.cache`. The generated helper files are pointedly **not** excluded. `vendor/` is never blanket-excluded — that would kill third-party symbol resolution.

## Livewire
`<leader>lw` (or `:LivewireToggle`) moves between the files that make up one component — the move neither plugin covers.

Livewire 4 ships **three** component shapes and `make:livewire` defaults to the one that didn't exist before, so the naive class↔view assumption from every Livewire 3 guide is wrong. Verified against livewire/livewire v4.3.3:

| Shape | Files |
|---|---|
| `--sfc` (default) | `resources/views/components/admin/⚡user-table.blade.php` — class **and** view in one file. `--emoji=false` drops the ⚡, making the path indistinguishable from an anonymous Blade component. |
| `--mfc` | directory `resources/views/components/billing/⚡invoice/` holding `invoice.php` + `invoice.blade.php` (+ optional `.js` / `.css`) |
| `--class` (v3 legacy) | `app/Livewire/Reports/Sales.php` + `resources/views/livewire/reports/sales.blade.php` — Livewire 2 used `app/Http/Livewire` |

`require("laravel.livewire").related(root, file)` returns every sibling of whichever shape the current file belongs to, plus a `kind` (`class` / `view` / `mfc` / `sfc` / `none`), so one keymap covers all of them:

- **class** → its view; a `view('…')` inside the class wins over the naming convention, so custom views navigate correctly
- **view** → every class candidate that exists (a project can be mid-migration from `app/Http/Livewire`)
- **mfc** → the sibling `.php` / `.blade.php` / `.js` / `.css`, picked via `vim.ui.select`
- **sfc** → nothing to move to, and it says which shape it found rather than no-op'ing. The emoji-less variant is identified by content (`Livewire\Component`, `new class extends Component`, `Livewire\Volt`) since the path can't tell.

Kebab conversion matches Laravel's `Str::kebab` exactly, including runs of capitals (`APIToken` → `a-p-i-token`).

`wire:*` / `x-*` attribute completion and `<livewire:` / `<x-` **tag-name** completion are a separate blink source — see [[laravel-blade]]. `gf` on a component tag resolves through the same shape logic (lua/artisan/gf.lua).

## Coverage
`<leader>tc` in a Pest project needs its flags threaded through `pest_cmd`: neotest-pest's `build_spec` ignores `extra_args`, `env` **and** `cwd`, so the `NEOTEST_COVERAGE` variable the GAF phpunit wrapper reads never reaches pest. lua/config/neotest-coverage.lua sets an absolute cobertura target on lua/artisan/test.lua for the duration of the run, and checks up front that xdebug or pcov is actually loaded — without a driver pest writes no report and the poll would just sit there until it timed out.

## Related-file navigation
`gd` is the key to reach for, not `gf`. Following the shape `lua/angular/init.lua` uses, a buffer-local `gd` on php/blade tries the Laravel-aware resolvers and falls through to `Snacks.picker.lsp_definitions()` when none of them claims the cursor:

| Cursor on | Goes to |
|---|---|
| `<x-badge`, `<livewire:admin.user-table`, `@livewire('…')` | the component file, all four Livewire 4 shapes |
| `{{ $days }}`, `@if ($showArchived)`, `$this->save()` in a component's own template | the declaration line in its class — `app/Livewire/Reports/Sales.php:10`, on `public int $days = 30;` |
| `route('posts.show')`, `__('posts.empty')` | the `->name()` line / the translation key |
| `@include`, `view()`, `config()`, Inertia pages | via blade-nav's resolver |
| anything else | the language server |

Most of what you chase in a Blade view is a definition rather than a path, and intelephense is not attached to blade at all — so plain `gd` did nothing there before. `gf` still works and shares the same resolvers; it just ends at `normal! gf` instead of the LSP.

Livewire 4 **multi-file** components navigate with `<leader>oo` too — every member of a `⚡name/` directory shares the directory's base name, so `invoice.php` ↔ `invoice.blade.php` ↔ `invoice.js` ↔ `invoice.css` is expressible as an other.nvim pattern (the ⚡ is a literal). Livewire class ↔ **test** is wired both ways (`app/Livewire/X.php` ↔ `tests/{Feature,Unit}/Livewire/XTest.php`).

Class ↔ view for the legacy shape **is** wired: the view name is the kebab-case of the class path, and other.nvim's builtin `camelToKebap`/`kebapToCamel` transformers do exactly that conversion per path segment, so `app/Livewire/Reports/Sales.php` ↔ `resources/views/livewire/reports/sales.blade.php` round-trips. Single-file components have no second file, so `<leader>lw` (which reports the shape) remains the right key there.

Laravel projections were added to other.nvim (lua/plugins/other.lua) — `<leader>oo` / `<leader>os` / `<leader>oV`. Models ↔ tests/factory/policy/observer/resource, controllers ↔ tests/request/resource/model, events ↔ listeners, plus jobs/middleware/notifications/mail/commands → tests and both test layouts back to source. No path collision with the GAF `src/`, `src2/`, `consumers/` patterns, so they are registered in every profile.

Livewire class ↔ view is *not* a projection: the view name is the kebab-case of the class name, which other.nvim's `%1` substitution cannot express.

## See also
[[laravel-nvim]] · [[laravel-blade]] · [[laravel-blade-nav]] · [[format-conform]] · [[format-nvim-lint]] · [[dap-nvim-dap]]
