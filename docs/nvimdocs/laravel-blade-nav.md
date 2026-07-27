# laravel-blade-nav
> `gf` and completion for Blade references: includes, components, Livewire, routes.

**Repo:** https://github.com/RicardoRamirezR/blade-nav.nvim
**Local spec:** lua/plugins/laravel.lua:79
**Tags:** blade laravel livewire gf navigation inertia completion

## Scope
Resolves the *reference* under the cursor to the file it names. Where laravel.nvim asks the application, this one reads the project layout.

With the handlers we keep, it resolves: `@include`, `@includeIf`, `@includeWhen`, `@includeUnless`, `@includeFirst`, `@component`, `@each`, `view()`, `config()`, `env()`, `Inertia::render()` and Vue imports. When the target does not exist it offers to create it.

Its Livewire, component and route handlers are switched off — see below.

## Keymaps
| Key | Action |
|---|---|
| `<leader>lv` | Toggle inline `config()`/`env()`/translation value annotations |
| `<leader>lC` | Clear the plugin's cache |

Its own `gf` is **disabled** (`integrations.gf = false`) — lua/artisan/gf.lua owns the key and calls this plugin's resolver as one step. See [[laravel-nvim]] for why.

## Our config
```lua
opts = {
  annotations = { create_keymaps = false },
  integrations = { gf = false },
  handlers = { livewire = false, component = false, route = false },
}
```

### Disabled handlers
All three were verified broken against Laravel 13 / Livewire 4 and are answered by `lua/artisan/` instead:

| Handler | Why |
|---|---|
| `livewire` | scans only `resources/views/livewire`, the Livewire 3 layout. In a stock Livewire 4 app it found **1 of 4** components, and its `gf` offered four paths that do not exist. |
| `component` | scans **all** of `resources/views/components`, which in Livewire 4 also holds Livewire components — so it offered `<x-admin.⚡user-table />`, not a valid tag. |
| `route` | shells out `artisan route:list --columns=name,action`; Laravel 13 removed `--columns`, so it silently resolves nothing. laravel.nvim's route completion works and is kept. |

Also note `__()` navigation: this plugin looks in `resources/lang`, but Laravel 9+ moved translations to `lang/` at the project root, so lua/artisan/refs.lua handles translations too.


**This one matters.** `annotations.show` is off by default upstream but `annotations.create_keymaps` is not, and `annotations.setup()` runs unconditionally — so out of the box the plugin claims a **global `K`** (clobbering LSP hover everywhere, not just in blade) plus `<leader>bv` and `<leader>bcc`, which collide with the `<leader>b` buffer group. Disabling its keymaps and mapping its two user commands under `<leader>l` keeps `K` on `vim.lsp.buf.hover`.

## Completion
Native blink source at `blade-nav.integrations.blink`, registered by hand in lua/plugins/lsp.lua (the module documents manual wiring). Live contexts: `@include('`, `@extends('`, `view('`, `inertia('`, `config('`, `env('`. `<x-` and `<livewire:` come from the `livewire` source instead (lua/artisan/livewire_source.lua), and `route('` from laravel.nvim.

## Gotchas
- `setup()` returns early when the project has no `artisan`/`composer.json`, so no extra gating is needed for non-Laravel PHP. Load triggers are still emptied under `GAF=1` for the lazy-clean reason described in [[laravel-nvim]].
- Its `gf` deletes any pre-existing **buffer-local** `gf` on attach; nothing else in this config sets one on php/blade.

## See also
[[laravel-nvim]] · [[laravel-blade]] · [[laravel-tooling]]
