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
| `laravel_lsp` | `<x-` / `<livewire:` tag names, `@directives`, view/route/config/env/translation strings, plus hover, goto and diagnostics on all of them. See [[laravel-lsp]]. |
| `html` | tag + attribute completion. Treats `@directives` as text and emits no diagnostics. |
| `emmet_language_server` | `div>ul>li`, `.foo`, `!` abbreviations. |
| `tailwindcss` | class completion/hover/lint. Only starts where a tailwind config exists. |

**`phpantom_lsp` is deliberately NOT attached** (`filetypes = { "php" }`). It cannot parse `@if`/`@foreach`, so attaching it trades a little completion inside `{{ }}` for a syntax error on every directive. Blade's framework intelligence comes from `laravel_lsp`, which parses Blade properly; what neither covers is filled by the `livewire` source below.

### Tailwind in Blade/Livewire
`experimental.classRegex` is extended (lua/artisan/lsp.lua) beyond the default `class="…"` matcher, since Laravel hides classes in places Tailwind's own matcher never looks:

- `@class([ 'p-4' => $cond ])`
- `wire:loading.class` / `wire:loading.class.remove`
- `x-bind:class` and `:class`

These are **JavaScript** regexes run inside the server, not Lua patterns.

## Completion sources (blink.cmp)
Neither `php` nor `blade` has a `sources.per_filetype` entry — both use `default`:

```
lsp → path → snippets → buffer
```

`lsp` on blade means `laravel_lsp` plus html/emmet/tailwind; on php it means `laravel_lsp` plus `phpantom_lsp`. There is **no custom provider**, by design — see [[laravel-lsp]] for what that costs.

A hand-written `livewire` source used to sit in front of `lsp` here, offering `wire:*` attributes, a tag's own props and `$prop` inside a component's template. It declared `: - . < > $ "` as trigger characters and carried `score_offset = 5`, so it competed with `laravel_lsp` at the same cursor positions and won — which made the server's own tag and string completion unreliable. Custom sources that overlap a server's trigger characters degrade it rather than supplement it.

The practical consequence: `wire:` and Alpine `x-` attribute names, their dot-modifiers, `wire:model=`/`wire:click=` values, a component's props as attributes, and `$prop` in its own template do not complete at all.

### Known limit: generic return types
`Livewire::test(Sales::class)->` may complete nothing. The facade documents `@return Testable<TComponent>`, and a PHP server that does not implement docblock generics cannot follow it. The workaround is a local type hint:

```php
/** @var \Livewire\Features\SupportTesting\Testable $c */
$c = Livewire::test(Sales::class);
$c->assertOk();   // completes
```

## Snippets
`snippets/blade.json` (~70), loaded by the existing LuaSnip vscode loader via snippets/package.json.

Control flow `if ife elseif unless isset empty for foreach forelse while switch` · layout `extends section sectioni yield parent include included includeif includewhen includefirst each component x slot props aware push pushonce prepend stack once verbatim fragment` · auth/env `auth guest can cannot canany env production error session hassection` · attributes `class style checked selected disabled required` · misc `php use csrf method vite json lang ee eee cc dd dump` · Livewire `livewire lw persist teleport lwscript lwassets entangle volt`.

Pest snippets are **not** here — see [[laravel-tooling]].

## Formatting
`blade` → `blade-formatter`, resolved project-first (`node_modules/.bin` → mason → `$PATH`) and condition-guarded on the project shipping it (lua/artisan/formatting.lua). Format-on-save applies as it does everywhere else.

## See also
[[laravel-lsp]] · [[laravel-nvim]] · [[laravel-tooling]] · [[format-conform]] · [[cmp-blink]]
