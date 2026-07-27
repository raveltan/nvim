# laravel-blade
> How `.blade.php` buffers get highlighting, completion, comments and formatting.

**Local spec:** lua/plugins/lsp.lua, lua/plugins/treesitter.lua, after/ftplugin/blade.lua, snippets/blade.json
**Tags:** blade laravel php treesitter tailwind emmet livewire alpine snippets blade-formatter

## Filetype — nothing to configure
Neovim's own runtime maps `*.blade.php` → `blade` (`$VIMRUNTIME/lua/vim/filetype.lua`, pattern `%.blade%.php$`). The `vim.filetype.add({ pattern = { ['.*%.blade%.php'] = 'blade' } })` snippet in nearly every Laravel/nvim blog post is **obsolete** — do not add it.

## Treesitter — nothing to configure either
`blade`, `php` and `php_only` are in the install list (lua/plugins/treesitter.lua:11), and nvim-treesitter `main` ships `runtime/queries/blade/{highlights,injections,indents,folds}.scm`. The FileType autocmd in the same file starts the parser and sets `indentexpr`/`foldexpr`. A blade buffer parses as three trees:

```
blade, php_only, javascript
```

so `{{ }}`, `@php` blocks and Alpine `x-data` expressions all highlight as their real language. The hand-written `highlights.scm` / `injections.scm` from tree-sitter-blade's discussion #19 are no longer needed.

**Auto-tags:** nvim-ts-autotag has no `blade` entry upstream, so `aliases.blade = "html"` is set in lua/plugins/treesitter.lua — without it blade views got no `</tag>` auto-close and no tag rename.

## Comments
Neovim ships no `ftplugin/blade.*`, so `commentstring` was empty and `gcc` silently did nothing. after/ftplugin/blade.lua sets `{{-- %s --}}`, and ts-comments.nvim gets a matching `lang.blade` entry (lua/plugins/editor.lua) so `//` is still used inside `@php` and `<script>` regions.

## Language servers attached to blade
| Server | Why |
|---|---|
| `html` | tag + attribute completion. Treats `@directives` as text and emits no diagnostics. |
| `emmet_language_server` | `div>ul>li`, `.foo`, `!` abbreviations. |
| `tailwindcss` | class completion/hover/lint. Only starts where a tailwind config exists. |

**`intelephense` is deliberately NOT attached** (`filetypes = { "php" }`). It cannot parse `@if`/`@foreach`, so attaching it trades a little completion inside `{{ }}` for a syntax error on every directive. PHP-level intelligence in blade comes from the completion sources below instead.

### Tailwind in Blade/Livewire
`experimental.classRegex` is extended (lua/artisan/lsp.lua) beyond the default `class="…"` matcher, since Laravel hides classes in places Tailwind's own matcher never looks:

- `@class([ 'p-4' => $cond ])`
- `wire:loading.class` / `wire:loading.class.remove`
- `x-bind:class` and `:class`

These are **JavaScript** regexes run inside the server, not Lua patterns.

## Completion sources (blink.cmp)
`sources.per_filetype.blade` (lua/plugins/lsp.lua):

```
livewire → blade_nav → laravel → lsp → snippets → path → buffer
```

| Provider | Module | Offers |
|---|---|---|
| `livewire` | `artisan.livewire_source` | Six contexts, see below |
| `blade_nav` | `blade-nav.integrations.blink` | `@include('`, `<x-`, `<livewire:`, `route('`, `config('`, `env('`, `__('`, Inertia pages |
| `laravel` | `laravel.extensions.completion.blink` | `view()`, `route()`, `config()`, `env()`, `Inertia::render()` strings and Eloquent column names |

`sources.per_filetype.php` is the same minus `livewire`.

### What the `livewire` source completes
This is the Livewire counterpart of the Angular `@Input` source (`lua/angular/inputs_source.lua`) — same idea, same treesitter-backed approach. It resolves, in priority order:

| Context | Offers |
|---|---|
| `wire:model="▏"` / `wire:text` / `wire:show` | the **enclosing component's** public properties, typed |
| `wire:click="▏"` / `wire:submit` / `wire:target` / … | its public **actions** (methods, minus Livewire's lifecycle hooks) |
| `{{ $▏ }}`, `@if ($▏)`, `$this->▏` | the component's own props and actions **inside its own template** — intelephense is not attached to blade, so without this nothing completes after `$` in a view |
| `<livewire:▏` / `<x-▏` | component tag names, all four Livewire 4 shapes |
| `<livewire:user-table ▏` / `<x-badge ▏` | that component's **props**, with type, default and docblock. A leading `:` is absorbed, so `:ti<Tab>` yields `:title="…"` |
| `wire:model.▏` | that directive's dot-modifiers |
| anywhere else in a tag | the generic `wire:*` / Alpine `x-*` attribute list (46 entries) |

Props come from `lua/artisan/props.lua`, which parses with treesitter rather than patterns:

- **Livewire class / sfc / mfc** — `property_declaration` nodes with `public` visibility (handles `public ?int $teamId = null`), plus `mount()` parameters, which Livewire binds from the tag exactly like properties. Docblocks come from the preceding `comment` sibling.
- **Anonymous Blade components** — the `@props([...])` argument list is re-parsed as PHP so it walks a real `array_element_initializer` tree. Splitting on commas would break on `'label' => 'a, b'` and on nested arrays; both are covered.

Results are cached per file, keyed on mtime+size, and carry the declaration's line number so `gd` can land on it.

### Known limit: generic return types
`Livewire::test(Sales::class)->` completes nothing. The facade documents `@return Testable<TComponent>`, and intelephense does not implement generics — confirmed both with and without `_ide_helper.php`, so `:LaravelIdeHelper facades` does not help. Everything either side of it works (`$component->` gives 94 items, `expect(1)->` gives 100). The workaround is a local type hint:

```php
/** @var \Livewire\Features\SupportTesting\Testable $c */
$c = Livewire::test(Sales::class);
$c->assertOk();   // completes
```

> Neither plugin registers its own blink source — laravel.nvim's boot only calls `cmp.register_source`, and blade-nav's blink module documents manual wiring. Both are registered by hand in lua/plugins/lsp.lua. Each source self-disables outside a Laravel project.

## Snippets
`snippets/blade.json` (~70), loaded by the existing LuaSnip vscode loader via snippets/package.json.

Control flow `if ife elseif unless isset empty for foreach forelse while switch` · layout `extends section sectioni yield parent include included includeif includewhen includefirst each component x slot props aware push pushonce prepend stack once verbatim fragment` · auth/env `auth guest can cannot canany env production error session hassection` · attributes `class style checked selected disabled required` · misc `php use csrf method vite json lang ee eee cc dd dump` · Livewire `livewire lw persist teleport lwscript lwassets entangle volt`.

Pest snippets are **not** here — see [[laravel-tooling]].

## Formatting
`blade` → `blade-formatter`, resolved project-first (`node_modules/.bin` → mason → `$PATH`) and condition-guarded on the project shipping it (lua/artisan/formatting.lua). Format-on-save applies as it does everywhere else.

## See also
[[laravel-nvim]] · [[laravel-blade-nav]] · [[laravel-tooling]] · [[format-conform]] · [[cmp-blink]]
