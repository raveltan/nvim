# editor-angular
> Angular component navigation with treesitter + ripgrep, no LSP: `gd` on tags/attrs/classes/expressions/routes, `<leader>cp` callers, `<leader>cG` component-by-name, `<leader>cR` URL → route module, plus a blink.cmp source that completes a component's `@Input`/`@Output`s while you type inside its tag — with types, doc comments, and enum value-seeding + auto-import.

**Local module:** lua/angular/init.lua (in-repo, not a plugin) + lua/angular/inputs_source.lua (blink source)
**Setup:** init.lua calls `require("angular").setup()` eagerly (cost: one FileType autocmd on `typescript`); the completion source is wired in lua/plugins/lsp.lua (blink provider `angular_inputs`)
**Tags:** angular, typescript, treesitter, ripgrep, navigation, gd, completion, blink, input, output

## Scope

Not GAF-specific — works in any Angular project; the Freelancer webapp is just the repo it was tuned in (GAF-only tooling stays in `lua/gaf/`). Tuned for **inline-template** Angular (`@Component({ template: `...` })`): the `angular` treesitter parser auto-injects into the template backtick string (see [ts-nvim-treesitter](ts-nvim-treesitter.md)), so tag/attribute names under the cursor are read precisely. Projects with external `.component.html` templates still get the `.ts`-side navigation (selectors, `@Input`/`@Output`, routes) but not the in-template reads that need the injected tree.

All lookups are treesitter (to classify what's under the cursor) + `rg --vimgrep` (to find the definition) — no language server. Single hit jumps straight; multiple hits open a Snacks picker.

Formerly gated behind `GAF=1` at `lua/gaf/angular.lua`; moved to `lua/angular/` and ungated because none of the navigation is GAF-specific.

## Keymaps (buffer-local, on `typescript` buffers)

| Key | Action |
|---|---|
| `gd` | Definition under cursor (Angular-aware, see below); falls back to `Snacks.picker.lsp_definitions()` on plain TS |
| `<leader>cp` | Parent components — files whose template uses this component's selector ("up"/callers) |
| `<leader>cG` | Prompt for a component name (class like `FooComponent`, prefix ok, or selector `app-foo`) → its definition |
| `<leader>cR` | URL/route string under cursor (`/messages/thread/${id}`) → the `path:` line in the routing module that handles it |

`<leader>cR` shares its key with typescript-tools `TSToolsRemoveUnused` ([prod-typescript-tools](prod-typescript-tools.md)); the Angular FileType autocmd registers after it (init.lua runs after lazy), so the route jump wins on TS buffers — pre-existing behaviour, unchanged by the move.

### What `gd` resolves

- **tag** (`<app-foo>`) → the component's `selector:` definition (picker when several files define the same selector)
- **attribute** (`[size]`, `(click)`, `flDir`) → the `@Input`/`@Output`/signal on the tag's component, else an attribute-selector directive
- **class binding** (`class="x"`, `[class.x]`, `ngClass`) → the `.x` rule in the component's own stylesheet (`styleUrls`), with SCSS `&`-nesting (BEM) suffix matching; offers to create the rule when missing
- **binding expression symbol** (`ButtonSize.SMALL`, `plainVar`) → PascalCase/CONST → a type/enum/class/const under the search root (landing on the member for `Enum.MEMBER`); lowerCamel → a class member in the component file
- **template-local** (`@if (…; as x)`, `@for` var, `@let`, `*ngIf="… as v"`, `#ref`, `<ng-template let-ctx>`) → the binding site (innermost enclosing scope wins); checked before the class-member search

## Inline-template input completion (blink.cmp)

While the cursor is inside a component's **open** start tag (`<app-foo …▏`), a blink source offers that component's members as completion items — `@Input`/`@Output` decorators **and** the signal APIs (`input()`, `input.required()`, `model()`, `output()`) — each showing its **type** in the menu's description column and a full signature in the docs popup.

- **Accepting** inserts the whole binding, cursor between the quotes: input → `[name]="▏"`, output → `(name)="▏"`, two-way model → `[(name)]="▏"`. An already-typed bracket (`[`, `(`, `[(`) is swallowed so it never doubles.
- **Trigger:** the binding brackets `[` and `(`, the enum-member dot `.`, plus normal keyword typing (blink's `show_on_keyword`). Space is deliberately *not* a trigger (would pop the menu after every space in a `.ts` file).
- **Aliases:** `@Input('alias') prop` / signal `{ alias: 'x' }` complete under the template name (the alias); the docs popup shows the underlying field.
- **Doc comments:** the JSDoc (`/** … */`) or `//` comment directly above an `@Input`/`@Output` shows in the completion docs popup, under the signature. Only a comment *adjacent* to the member is used (a gap means it documents something else).

### Enum types → value-seed + auto-import

When an accepted input's type is an **exported `enum`** (e.g. `@Input() size: ButtonSize`), the item is enriched (in blink's `resolve`, so only the focused item pays the cost):

- The value is seeded with the enum: accepting `size` inserts `[size]="ButtonSize.▏"` (not just `[size]="▏"`).
- The enum is **auto-imported** into the current file on accept (blink `additionalTextEdits`) — merged into an existing `import` from the same module when there is one, else added as a new line after the last import. Skipped when it's already imported or defined in this file.
- The enum is **exposed on the component class** as `ButtonSize = ButtonSize;` — the first field of the class body (the GAF idiom; a template can only reference class members, not imported symbols, so the seeded `Enum.MEMBER` would otherwise not resolve). Skipped when the class already exposes it. The class is found by walking up from the cursor (which sits in the `@Component` decorator's template) to the sibling `class_declaration` under the same `export_statement`.
- The docs popup lists the enum's members (`ButtonSize.SMALL · ButtonSize.MEDIUM · …`) and the resolved import path.

Both the import and the class-field are separate, non-overlapping `additionalTextEdits`, applied together on accept.

Resolution is one `rg` for `export … enum <Type>` under the search root, cached per type name (misses too), plus a treesitter parse of the enum file for its members. **Import path** assumes Angular's `baseUrl = src` (verified in the GAF webapp) and prefers the **barrel**, not a deep import: it walks up from the enum file to the nearest ancestor directory whose `index.ts` re-exports the symbol (named export, direct `export enum`, or any `export *`) and uses that directory's `src`-relative path — so `ButtonColor` (defined in `@freelancer/ui/button/button.types.ts`) imports as `@freelancer/ui/button`, not `@freelancer/ui/button/button.types`. Falls back to the file's own path when no barrel re-exports it. Outputs are left untouched (they bind handler expressions, not enum values). Multi-line `import { … }` blocks from the same module aren't merged into (a new line is added instead) — single-line imports merge cleanly.

### Enum members (`ButtonSize.▏` → `SMALL`, `MEDIUM`, …)

A second completion mode: with the cursor right after `SomeEnum.` **inside a template**, the source offers that enum's members (kind `EnumMember`, in declaration order). Triggered by `.` (and keyword typing). Each member also carries the import + class-field `additionalTextEdits`, so completing `ButtonSize.SMALL` by hand — without having gone through the input completion — still imports and exposes `ButtonSize`.

- **Template-gated:** only fires when the cursor is inside a `template_string`. In real TS code, `tsserver` already completes enum members (and it sees the template as an opaque string, offering nothing there), so there's no duplication.
- **Value vs. name context:** input/output-name completion is suppressed once the cursor is inside a quoted attribute value (`[size]="▏"`), so it never offers attribute names where a value expression belongs. Value completion (below) takes over there.
- Reuses `resolve_enum` (cached), so after the enum is first resolved, member completion is instant.

### Value completion by declared type (empty value, `[attr]="▏"`)

Inside a component input's value quotes — before typing anything — the source looks up that input's declared type and offers concrete values:

- **enum type** (incl. **nullable** `ButtonSize | null` and arrays `ButtonSize[]`) → the full `ButtonSize.SMALL`, `ButtonSize.MEDIUM`, … list, each carrying the import + class-field edits. The `| null` / `| undefined` / `readonly` / `[]` decorations are stripped to find the name (`enum_name_of`).
- **string-union `type` alias** — a named type like `export type FlexDirection = 'column' | 'row'` (how GAF models many "string enums") — resolves via `resolve_type` to its literal values and offers them like a union. Nullable (`FlexDirection | null`) works too. No import is added (a bare string literal needs none).
- **inline string/number-literal union** (`'primary' | 'secondary' | 'ghost'`, `1 | 2 | 3`) → each literal. In a property binding (`[variant]="▏"`) the value is an expression, so `'primary'` is inserted **quoted**; in a static attribute (`variant="▏"`) it's inserted **bare** (`primary`). A union with any non-literal (non-`null`) member is not offered.

This is driven by the attribute name to the left of the cursor (`value_attr`) → the component's input list (`tag_inputs`) → the input's type (`classify_type`, then `resolve_type` for a named type). `resolve_type` classifies a named type as `enum` (members) or a literal-union `type` alias in one `rg` (both `export enum` and `export type` patterns), cached per name. It runs only when the enum-member (`Enum.`) path above didn't already claim the completion, so the two never double up.

**Why a text scan, not treesitter, to find the enclosing tag:** while an attribute is being typed the tag is unclosed, and treesitter's error recovery misattributes the cursor to the nearest *well-formed enclosing* element (cursor in `<app-foo [` resolves to the surrounding `<div>`). `enclosing_tag_name` instead takes the last `<tag` before the cursor with no intervening `>` — exactly the "inside an open start tag" state. False hits (a `<` in a binding expression, a TS generic like `Array<`) are discarded by the caller's `-`-in-name gate, since component selectors always contain a dash.

**Speed (the "relatively quickly" requirement):** two caches. `selector → component file` (never invalidated — selectors rarely move) and `file → member list` (keyed on mtime). Only the first completion on a fresh tag pays one async `rg` for the selector's file; every keystroke after is a table read, so the menu stays responsive.

**Extraction** (`parse_inputs`) reads the component file off disk and treesitter-queries every `class_body`: decorated fields/setters (`@Input`/`@Output`, honoring string aliases and setter param types), and signal fields whose initializer calls `input`/`model`/`output` (type from the `<T>` generic, alias from an options object). `notInput = 42` and other plain fields are excluded. Results dedupe by binding name.

**Limits:** no type-checking (not a language server); value completion covers `enum` types (incl. nullable) and string/number-literal unions — other named types (interfaces, non-literal unions) insert a bare `""`; a file with multiple component classes merges their members; `>` inside an attribute value (`[x]="a > b"`) can break the backward scan on that tag.

## Public API (`require("angular")`)

- `.goto_definition()` → `true` when the cursor was on an Angular template target and it claimed the jump (even if unresolved); `false` only on plain TS, so the caller can fall through to LSP.
- `.goto_parents()`, `.goto_component_prompt()`, `.goto_route()` — the `<leader>c{p,G,R}` actions.
- `.setup()` — registers the FileType autocmd + keymaps (called once from init.lua).
- `.component_inputs(cb)` → resolves the component tag under the cursor to its member list and calls `cb(inputs, { tag, file })`, or `cb(nil)` when the cursor isn't inside a component tag. Async only on a selector cache miss (one `rg`). Consumed by the blink source in lua/angular/inputs_source.lua.
- `.resolve_type(type, cb)` → `cb({ kind="enum", name, file, spec, members })` or `cb({ kind="union", name, file, spec, values })` for an exported enum or string/number-literal `type` alias; else `cb(nil)`. Cached per normalized name (handles nullable). Drives value completion.
- `.resolve_enum(type, cb)` → the enum-only view of `resolve_type` (for `Enum.` member completion + attr seeding).
- `.template_enum_members(cb)` → `cb(members, enumName, enumInfo)` when the cursor is inside a template right after `Enum.` and `Enum` resolves to an exported enum; else `cb(nil)`. Drives enum-member completion.
- `.template_value_completions(cb)` → `cb(spec, meta)` when the cursor is inside a component input's value and its type is completable: `spec = { kind = "enum", enum, en }` or `{ kind = "union", values, is_binding }`; else `cb(nil)`. Handles nullable enums (`Enum | null`) and string/number-literal unions.
- `.build_import_edit(bufnr, name, spec, deffile)` → an LSP TextEdit importing `name` from `spec` into `bufnr`, or `nil` if already imported / defined there / spec unknown.
- `.build_enum_field_edit(bufnr, name)` → an LSP TextEdit adding `name = name;` as the first field of the component class enclosing the cursor, or `nil` if already present / no class found.

## Notes

- **Search root** for `rg`: nearest `webapp/src` ancestor, else `webapp`, else `src`, else cwd — narrows to the Angular source tree without a config knob.
- **Route walk** (`<leader>cR`) descends from `src/app/app-routing.module.ts`, crossing `loadChildren` lazy boundaries into `*-routing.module.ts` siblings and `RouterModule.forChild(...)` arrays; `${…}` interpolations match `:param` segments. Best-effort fallback to the deepest match / wildcard for `matcher:`/`redirectTo` routes.
- Reads routing files off disk (`vim.fn.readfile` + `get_string_parser`), not through buffers, so it works from any file in the tree and across git worktrees.

## Links

- Tag jumping / rename (separate module): [editor-tagmatch](editor-tagmatch.md)
- Class rename shares the styleUrls/BEM logic: [config-rename](config-rename.md)
- Template injection that powers in-template reads: [ts-nvim-treesitter](ts-nvim-treesitter.md)
- Related-file picker for `.ts` ↔ `.scss`/`.spec` etc.: [workflow-other](workflow-other.md)
- Key overlap: [prod-typescript-tools](prod-typescript-tools.md)
