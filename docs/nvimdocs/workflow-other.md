# workflow-other
> Jump between related files (test ↔ source, component ↔ styles, handler ↔ service…).

**Repo:** https://github.com/rgroli/other.nvim
**Local spec:** lua/plugins/other.lua:29
**Tags:** workflow navigation related-files php angular datastore

## Scope
Lazy-loaded on `Other*` commands and `<leader>o{o,s,V}`. Pure pattern-matching: each rule has a Lua-pattern `pattern` capturing `%1` (and sometimes `%2`) and a list of candidate `target` paths with human-readable `context` labels. `showMissingFiles = false` means the picker only lists files that actually exist, so we can offer many candidates without noise.

## Install spec
```lua
{
  "rgroli/other.nvim",
  main = "other-nvim",                                   -- module name is "other-nvim", not "other"
  cmd = { "Other", "OtherSplit", "OtherVSplit", "OtherClear" },
  opts = {
    rememberBuffers = false,
    showMissingFiles = false,
    style = { border = "rounded", width = 0.4, minHeight = 8, seperator = "|", newFileIndicator = "(+)" },
    mappings = { ... },                                  -- see below
  },
}
```

## Common customizations
- `mappings` *(table[])* — list of `{ pattern, target }` rules. `target` is either a single string or a list of `{ target, context }` tables.
- `rememberBuffers` *(bool, true)* — cache the last picked sibling per buffer. We disable so `<leader>oo` always re-resolves.
- `showMissingFiles` *(bool, true)* — show non-existent targets. We disable so wide-net rules stay tidy.
- `style.border`, `style.width`, `style.minHeight` — picker float appearance.
- `style.seperator` *(string, "|")* — **upstream typo**, preserved in plugin source. Don't "fix" it.
- `style.newFileIndicator` *(string, "(+)" )* — suffix shown next to missing targets when `showMissingFiles = true`.

## Our config
~620 lines of mappings covering four domains: PHP legacy (`src/`), PHP new (`src2/`), Angular webapp, Angular datastore. **Rails navigation was removed (Jun 2026)** — it now lives entirely in vim-rails (`:A`/`:R`/`:E*` + projections), see [[ruby-vim-rails]]. vim-rails is context-aware (`:R` from a controller action jumps to *that* action's view), which flat pattern rules here could not be.

### PHP legacy (`src/`)
- `src/<M>/Foo.php` ↔ `test/unit/src/<M>/FooTest.php` / `test/functional/src/<M>/FooFunctionalTest.php` / `test/double/<M>/Foo.php` (infra mocks for `src/Core/{Grpc,Rabbit}`).

### PHP new (`src2/`)
- Per-type rules for `Handler`, `Service`, `Controller`, `Command`, `Repository`, `DTO`, `Enum`, `Traits` — each offers both the keep-Type test path (`test/unit/src2/Handler/FooTest.php`) and drop-Type alt (`test/unit/src2/FooTest.php` — used by SwiftId, Verification/...).
- Cross-type sibling navigation: from `Handler/Foo/FooHandler.php`, the picker offers `Service/Foo/FooService.php`, `Controller/...`, `Repository/...`, `Command/...`, `DTO/...`, plus `FooHandlerInterface.php`. Same pattern for every other src2 type.
- `Controller/AjaxApi/<X>Controller.php` has a special rule because cross-type siblings live one folder up (no `AjaxApi/` segment).
- Interface ↔ implementation: `src2/<X>Interface.php` ↔ `src2/<X>.php` (same folder, strip suffix). Same for `src/`.
- RabbitMQ consumers: `consumers/Foo.php` ↔ `test/functional/consumer/FooConsumerTest.php` only (the consumer↔handler naming convention is unreliable — only 3 of 222 follow it).

### Angular webapp (inline templates)
- `*.component.ts` hub jumps to `.scss`, `.spec.ts`, `.module.ts`, `-routing.module.ts`, `.routes.ts`, `.types.ts`, `.model.ts`, `.helpers.ts`/`.helper.ts`, `.resolver.ts`, `.config.ts`, `.interface.ts`, `.animation.ts`, `.validators.ts`, `.service.ts`, `.guard.ts`, `-guard.service.ts`, `-route-matcher.ts`.
- `*.service.ts` hub jumps to `.spec.ts`, `.types.ts`, `.model.ts`, `.validators.ts`, `.interface.ts`, `.config.ts`, `.helpers.ts`, `.helper.ts`, `.effect.ts`, `.module.ts`, `.component.ts`.
- `*.directive.ts` / `*.pipe.ts` each have a small hub (spec, types, animation/module).
- `*.module.ts` jumps to routing/component/routes/service + datastore siblings.
- `*-routing.module.ts`, `*.routes.ts`, `*.resolver.ts`, `*.guard.ts`, `*-guard.service.ts`, `*-route-matcher.ts`, `*.helpers.ts`, `*.helper.ts`, `*.effect.ts`, `*.interface.ts`, `*.config.ts`, `*.animation.ts`, `*.validators.ts`, `*.validator.ts` each have a tailored sibling list.

### Angular datastore collections (`@freelancer/datastore`, `@escrow/datastore`)
- Hub files `*.{backend,backend-model,model,reducer,seed,transformers,transformer,types}.ts` all jump to every sibling in the collection folder. `.model.ts` and `.types.ts` straddle datastore + feature folders so they list both groups.

### Storybook + generic fallback
- `<folder>/stories/<x>.story.ts` jumps up to `../<folder>.component.ts` (and directive/pipe/service/module/types).
- Generic fallback: `*.spec.ts` ↔ `*.ts` catches every spec file not covered by a specific rule (`*.helpers.spec.ts`, `*-guard.service.spec.ts`, etc.).

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>oo` | n | `:Other` | Picker; opens in current window |
| `<leader>os` | n | `:OtherSplit` | Picker; opens in horizontal split |
| `<leader>oV` | n | `:OtherVSplit` | Picker; opens in vertical split |

## GAF integration
Not gated by `vim.g.gaf` — pattern rules are inert when paths don't match, so leaving them globally enabled costs nothing. The src/src2/consumers patterns are tuned to the Freelancer GAF monorepo layout. AjaxApi aggregator controllers (e.g. `BusinessBuilderController`) won't find a 1:1 sibling — use LSP `gd` on the import instead.

## Links
- README: https://github.com/rgroli/other.nvim

## Notes
- `main = "other-nvim"` is mandatory because lazy.nvim guesses module name as `other` from the repo name; the actual module is `other-nvim`. Without this, `:Other` errors with "module not found".
- The `seperator` key (sic) is a known upstream typo — don't try to use `separator`, it's silently ignored.
- For rules with multiple `target` candidates, the picker labels each entry with its `context` string (e.g. "service | handler | controller") so you can pick by role at a glance.
- `(.*)%.spec%.ts$` → `%1.ts` lives at the bottom on purpose — more-specific patterns earlier in the list win.
