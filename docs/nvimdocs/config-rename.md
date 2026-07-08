# config-rename
> Context-smart `<leader>cr`: CSS class rename (cross-file, scss `&`-nesting aware) → tag-pair rename → LSP symbol rename.

**Local files:** lua/config/rename.lua (routing + class rename), lua/config/scss.lua (scss nesting resolver)
**Tags:** config, rename, css, scss, bem, angular, tags, lsp

## Scope

`<leader>cr` (lua/config/keymaps.lua:49) tries three backends in order; each returns `false` when the cursor context doesn't match, falling through to the next:

1. **CSS class rename** — cursor on a class name (in a `class="..."` / `className` / `[ngClass]` value, an Angular `[class.foo]` binding, or a `.foo` / `&-foo` selector in a css/scss buffer).
2. **Tag rename** — cursor on a tag name → `require("tagmatch").rename()` updates the open/close pair (see [editor-tagmatch](editor-tagmatch.md)). Uppercase JSX/Vue components with a rename-capable LSP are deferred to LSP rename instead (LSP updates the definition and all usages).
3. **LSP symbol rename** — the original hand-rolled rename incl. the intelephense `$` sigil workaround ([config-keymaps](config-keymaps.md)).

## Class rename

Component-scoped and cross-file:

- **From a template** (html, or Angular inline template in a `.ts` buffer): stylesheets are resolved via the component's `styleUrls`/`styleUrl` (same convention gaf `gd` uses), falling back to a same-stem sibling `.scss`. Rewrites happen in both the template and the stylesheets.
- **From a scss buffer**: cursor on `.X` or directly on `&-suffix` — the resolver walks the nesting to the full class name (`.Header { &-main }` → `Header-main`) — and the sibling template (`stem.html` or `stem.ts`) is updated too.
- **`&`-nesting**: `lua/config/scss.lua` parses the block tree, resolves `&` concatenation, and rewrites the `&-main` token itself (`Header-main → Header-primary` edits `&-main` → `&-primary`).
- **Cascades**: deeper nests follow automatically — renaming `Header-main` also maps `Header-main-title` (built from a nested `&-title`); renaming the block `Header` cascades every BEM child. Implemented by resolving the tree twice (original vs patched raws) and diffing class tokens positionally. Cascaded pairs are listed in the notify message.
- **Template rewrites** touch class-like attribute values, `[class.x]` bindings, and `.x` selectors inside `<style>` blocks — never bare JS property access (`obj.active` is safe).
- Touched files are written (same UX as the LSP rename's `silent! wall`).

### Safety rails

- A rename that can't be expressed with `&` (`Header-main` → `Nav-main` drops the parent prefix) is **warned and skipped** at that site, never guessed.
- If *no* definition site could be rewritten in the scoped stylesheets, the template is left untouched (error notification) so files don't desync.
- `&-x` shared by several parents (`.A, .B { &-x }`) where only some build the target: skipped with a warning.
- Unnamed buffers patch in place, no write.

### Known limits

Multi-line class attributes, `#{...}` interpolation (harmless phantom blocks in the resolver), comma groups inside `:not()`, and component scope — a class shared across components still wants grug-far (`<leader>sr`) where the diff is reviewable.

## Links

- Tag rename backend: [editor-tagmatch](editor-tagmatch.md)
- LSP fallback + `$` sigil handling: [config-keymaps](config-keymaps.md), [ftplugin-php](ftplugin-php.md)
- styleUrls convention shared with Angular `gd`: [editor-angular](editor-angular.md) — `lua/angular/init.lua` (`bem_suffixes`, `stylesheet_paths`)
- Project-wide alternative: [editor-grug-far](editor-grug-far.md)
