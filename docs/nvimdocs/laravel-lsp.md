# laravel-lsp
> The first-party Laravel language server: framework strings, component tags, directives.

**Repo:** https://github.com/laravel/lsp
**Local spec:** lua/plugins/lsp.lua (the `laravel_lsp` block)
**Tags:** laravel blade livewire lsp routes views config translations inertia middleware

## What it is
`laravel/lsp`, announced at Laracon US 2026. Installed with `composer global require laravel/lsp`, which puts a PHAR on `$PATH` as `laravel-lsp`. It has no mason package and nvim-lspconfig ships no config for it, so both the server name and the definition are ours.

> Do **not** name it `laravel_ls`. That name belongs upstream to `laravel-ls/laravel-ls`, an unrelated third-party Go server which *is* in mason. Two different projects, one obvious collision.

## It complements the PHP server, it does not replace it
The advertised capabilities are `completion`, `hover`, `definition`, `documentLink` and quickfix `codeAction`, plus pushed diagnostics. There is **no rename, no references, no document or workspace symbols, no formatting, no signature help**. Every provider resolves a *framework string literal* — it knows nothing about ordinary PHP.

So `phpantom_lsp` keeps its job (general PHP semantics) and this runs alongside it on `php`. The only overlap is a duplicate hover/definition on Laravel strings, where laravel_lsp is the one with the right answer.

## Our config
```lua
if vim.fn.executable("laravel-lsp") == 1 then
  vim.lsp.config("laravel_lsp", {
    cmd = { "laravel-lsp" },
    filetypes = { "php", "blade" },
    root_markers = { "artisan" },
    init_options = { pestGenerateDocBlocks = false },
    before_init = function(params, config) ... end,
  })
  vim.lsp.enable("laravel_lsp")
end
```

`root_markers` is **`artisan` alone**, unlike the README's `{ artisan, composer.json, .git }`. The server hard-errors with `Initialize request root URI must be a Laravel project` when handed a root with no `artisan` file, so the wider markers can only select a root it will then refuse. This is also what makes it inert in fl-gaf: PHP, but no `artisan`, so it never starts.

`pestGenerateDocBlocks` defaults to **true** and writes `storage/framework/testing/_pest.php` into the project. Pest completion here comes from LuaSnip ([[laravel-tooling]]), so it is off.

`phpEnvironment` is set in `before_init` rather than in the static `init_options`, because one `vim.lsp.config` serves every project opened in the session and the environment is a property of the root. `artisan.env()` already resolves it from disk for conform/nvim-lint/dap. Its `sail` and `local` pass straight through; its third answer, `docker` (a compose file with no sail wrapper), has no counterpart in the server's `auto|herd|valet|sail|lando|ddev|local` list, so that case falls back to `auto` and lets the server probe.

## It boots your application
Every data refresh shells out to `php artisan tinker --execute`. Consequences worth knowing:

- `laravel/tinker` must be installed and the app must boot cleanly. A boot-time fatal yields no data and reports nothing in the editor — failures only reach the server's log file.
- Eloquent completion calls `model:show`, which introspects real columns, so it needs a **live database connection**.
- Opening an untrusted clone executes that project's code on your machine.

## Verified coverage
Measured against a Laravel 13 / Livewire 4 / Flux app on v0.0.29.

| Context | Result |
|---|---|
| `<x-` | 524 items — app, vendor and Flux components |
| `<livewire:` | 4 items — all four components of the app, every Livewire 4 shape |
| ↑ but only on the bare trigger | see [Tag completion fires once](#tag-completion-fires-once) |
| `@directive` | 112 items, with snippet bodies |
| `config('` | 722 items, each showing its **resolved value** |
| `__('` | 147 items, each showing the **translated string** |
| `view('` | 127 items |
| `route('` | 25 items, with controller action and `[METHOD] /uri` |
| `gd` on `@include`, `@extends` | the view file |
| `gd` on `route()`, `__()`, `config()` | the `->name()` line, the lang file, `config/*.php` |
| diagnostics | `Route [x] not found.`, `Config [x] not found.`, `Translation [x] not found.`, `View [x] not found.` — including inside `@include`/`@extends`/`@each` |

Also covered per upstream: `env()` (with a Vite quickfix), `asset()`/`mix()`, middleware, gates and policies, container bindings, Inertia pages, validation rules, controller actions, storage disks.

## Verified gaps
These return **zero** items and nothing else in the stack covers them, so they simply do not complete:

- `wire:` / `x-` attribute **names** and their dot-modifiers
- a component's own props offered as attributes — `<x-auth-header ▏`, `<livewire:settings.profile ▏`
- `wire:model="▏"` / `wire:click="▏"` **values**
- `{{ $▏ }}` and `$this->▏` inside a component's own template

### Tag completion fires once
Component-tag completion answers the **bare trigger only**. Measured on the same project:

```
<x-              -> 524      <x-a   -> 0      <x-au -> 0      <x-auth-header -> 0
<livewire:       ->   4      <livewire:s      -> 0
<x-settings.     ->   0      <x-flux::        -> 0
```

The 524-item response is a plain array with no `isIncomplete`, i.e. a *complete* list, so filtering as you type is correctly the client's job and blink narrows the cached list. The rough edge is that `.` and `:` are both declared trigger characters, so a re-request part-way through a dotted or namespaced name (`<x-settings.layout`, `<x-flux::icon.x`) asks the server again and gets nothing back.

Two more, currently unanswered by anything:

- **completion** inside `@include('▏')` / `@extends('▏')`. Definition and diagnostics work there, completion does not — the server recognises the range but offers nothing.
- Eloquent attributes needed a live DB in testing; `User::where('▏')` returned nothing against a project with no connection.

Pre-1.0 (`v0.0.29`), so expect all of this to move.

## See also
[[laravel-blade]] · [[laravel-nvim]] · [[laravel-tooling]] · [[lsp-nvim-lspconfig]]
