# snippets-dir
> Local VS Code-format snippet pack consumed by LuaSnip and edited by scissors.

**Local spec:** snippets/
**Tags:** snippets, gaf, php, ruby, typescript, laravel, livewire, filament, pest

## Scope

`~/.config/nvim/snippets/` is a self-contained VS Code snippet "extension". It is loaded by LuaSnip's `from_vscode` loader (see [[cmp-luasnip]]) and edited in place by `scissors.nvim` (see [[editor-scissors]]). Each filetype has one JSON file; snippets are written once and instantly available in both engines.

## Structure

```
snippets/
├── package.json   manifest mapping language -> json file
├── php.json       PHP + GAF Phoenix (Controller/Handler/Repo/DTO/Enum/Test) + PHPDoc
├── blade.json     Blade directives, components, Livewire tags/directives
├── ruby.json      Rails controllers, models, ERB form helpers, RSpec, etc.
├── eruby.json     ERB tag wrappers and form helpers
├── typescript.json GAF Angular components, RxJS, signals, etc.
├── laravel/       Laravel 13 + Livewire 4 + Filament v5 (php + blade), non-GAF only
└── pest/          Pest 5 (registered under the synthetic `pest` filetype), non-GAF only
```

`laravel/` and `pest/` are separate packs with their own `package.json` because LuaSnip's
registry is global: loading them in the GAF profile would put `lmodel`, `filres` and `it`
in the completion menu of every PHP buffer in the monolith. Both are loaded from
[[cmp-luasnip]] behind `if not vim.g.gaf`.

### package.json

VS Code extension manifest stub. LuaSnip uses `contributes.snippets[]` to discover which JSON file backs which filetype.

```json
{
  "name": "rtanjaya-snippets",
  "contributes": {
    "snippets": [
      { "language": ["typescript"], "path": "./typescript.json" },
      { "language": ["php"],        "path": "./php.json" },
      { "language": ["ruby"],       "path": "./ruby.json" },
      { "language": ["eruby"],      "path": "./eruby.json" }
    ]
  }
}
```

To add a new filetype: drop `<ft>.json`, register it under `contributes.snippets`, restart nvim (or `:Lazy reload LuaSnip`).

### JSON snippet format

Each snippet is a key whose value is `{ prefix, description, body }`:

```json
"PHP arrow fn": {
  "prefix": "afn",
  "description": "arrow fn",
  "body": ["fn(${1:\\$x}) => ${0}"]
}
```

- `prefix` is what you type to trigger.
- `body` is an array of lines; `${1:default}`, `${0}`, `${1|a,b|}` follow LSP/TextMate syntax.
- `\\$` escapes `$` so PHP sigils don't collide with tab-stop syntax.

## scissors integration

[[editor-scissors]] writes to these same files:

- `:ScissorsAddNewSnippet` appends a new entry to the JSON file for the current filetype.
- `:ScissorsEditSnippet` opens an existing snippet in a popup editor and rewrites the JSON on save.
- Files stay valid JSON; scissors handles escaping.

## GAF integration

`php.json` is the GAF cheat-sheet:

- `fl-controller` — Phoenix controller with MethodNotAllowed guard.
- `fl-handler` — Handler with optional-dependency constructor pattern.
- `fl-repo` / `fl-repo-fetch` — Repository class + try/catch fetch using `MySql::fetchOne`.
- `fl-dto` — Immutable DTO with promoted constructor.
- `fl-enum` / `fl-enum-native` — MyCLabs Enum and PHP 8.1 native enum.
- `fl-mysql-one|all|insert|exec` — `Freelancer\Phoenix\Service\MySql` call sites.
- `fl-test-fn` / `fl-test-unit` — FunctionalTestCase / TestCase skeletons.
- `fl-consumer` — RabbitMQ consumer with retry-aware reject handlers.
- `fl-inject` — Optional dep injection with `??` fallback.
- `fl-bad-req` / `fl-not-found` / `fl-mna` — Common exception throws.
- `xdc` — `xdebug_connect_to_client()` for remote debugging consumers.

`typescript.json` mirrors the GAF Angular conventions (non-standalone OnPush component, `inject()` DI).

## Laravel pack (`snippets/laravel/`)

Tracks Laravel 13 (released 2026-03-17, PHP 8.3+), Livewire 4 and Filament v5. Prefixes are
namespaced so nothing collides with the GAF `fl-*` set or the stock Blade set.

`php.json` — `l*` Laravel, `lw*` Livewire, `fil*` Filament:

- `lmodel` `lcasts` `lscope` `lattr` `lbelongsto` `lhasmany` `lhasone` `lbelongstomany` `lmorphmany`
  — model with the `casts()` method (not the removed `$casts` property) and the `#[Scope]` attribute.
- `lmig` `lmigtable` — anonymous-class migrations.
- `lctl` `lctli` `lauthz` `lreq` `lres` `ljsonapi` `lmw` — controllers using Laravel 13's
  `#[Middleware]` / `#[Authorize]` attributes, plus the new `JsonApiResource`.
- `lroute` `lrouteres` `lroutegroup` `lroutelw` — routes, including Livewire 4's `Route::livewire()`.
- `ljob` `lqroute` `levent` `llistener` `lnotif` `lmail` — jobs carry `#[Tries]` / `#[Timeout]`
  (`Illuminate\Queue\Attributes\*`); `lqroute` is Laravel 13's `Queue::route()`.
- `lpolicy` `lobserver` `lprovider` `lcmd` `lfactory` `lseeder` `lrule` `lcast` `lenum`.
- `lvalidate` `ltx` `lcache` `lcachetouch` `lquery` — `lcachetouch` is Laravel 13's `Cache::touch()`.
- `laiprompt` `laiimage` `laiaudio` `laiembed` `lvector` — Laravel AI SDK + `whereVectorSimilarTo()`.
- `lwclass` `lwcomputed` `lwvalidate` `lwon` `lwdispatch` `lwurl` `lwlocked` `lwform` `lwpaginate`
  `lwupload` `lwlayout` — class-based Livewire components and their attributes.
- `filres` `filform` `filtable` `filinfolist` `filfields` `filsection` `filcol` `filfilter`
  `filaction` `filwidget` `filpage` `filrel` — Filament v5's unified schema API
  (`Filament\Schemas\Schema`, `Filament\Actions\*`, `recordActions()` / `toolbarActions()`).

`blade.json` — Livewire 4 markup:

- `lwsfc` — single-file component (`resources/views/components/⚡name.blade.php`).
- `island` `islandname` `islandlazy` `islanddefer` `placeholder` `wisland` — islands.
- `wmodel` `wclick` `wsubmit` `wloading` `wnavigate` `wpoll` `wconfirm` `wkey` `wignore` `wdirty`
  `wtransition` `wshow` `wtext` `wbind` `wref` `wsort` `wstream` `lwslot` `lwattrs`.

Volt is deliberately not covered — normal Livewire only.

The Pest pack additionally carries Pest 5: `pvisit` `pbrowser` `psmoke` `pa11y` `pdevice` `pshot`
(browser plugin), `peval` (evals plugin), `plw` `pjson` `pinvalid` `pqueue` `pmail` `pevent`
`pstorage` `ptravel`.

## Links

- VS Code snippet syntax: https://code.visualstudio.com/docs/editor/userdefinedsnippets
- scissors.nvim: https://github.com/chrisgrieser/nvim-scissors
- Laravel 13 release notes: https://laravel.com/docs/13.x/releases
- Livewire 4 components / islands: https://livewire.laravel.com/docs/4.x/components
- Filament v5 resources: https://filamentphp.com/docs/5.x/resources/overview
- Pest browser testing: https://pestphp.com/docs/browser-testing

## Notes

- Files are mtime-watched by LuaSnip's lazy_load — saving via scissors causes a reload on next BufEnter of that filetype.
- Keep `prefix` values short and namespaced (`fl-` for GAF-specific, `doc*` for PHPDoc) to avoid menu clutter.
- Lua-DSL snippets are NOT used here — everything is JSON so scissors can round-trip edit them.
