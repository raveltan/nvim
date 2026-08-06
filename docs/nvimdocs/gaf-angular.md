# gaf-angular
> Angular component navigation with treesitter + ripgrep, no LSP: `gd` on tags/attrs/classes/expressions/routes, `<leader>cp` callers, `<leader>cG` component-by-name, `<leader>cR` URL → route module, plus a blink.cmp source that completes component **tags** (`<fl-bu` → the whole element, auto-imported and wired into `imports:`/the owning `@NgModule`) and, inside a tag, that component's `@Input`/`@Output`s — with types, doc comments, and enum value-seeding + auto-import.

**Local module:** lua/gaf/angular/init.lua (in-repo, not a plugin) + lua/gaf/angular/inputs_source.lua (blink source) + lua/gaf/angular/selector_index.lua and lua/gaf/angular/module_index.lua (the two repo-wide indexes tag completion reads)
**Setup:** `require("gaf").setup()` calls `require("gaf.angular").setup()` under `GAF=1` only (cost: one FileType autocmd on `typescript`, one `BufWritePost *.ts` autocmd that patches the indexes, and the `:AngularReindex` command); the completion source is wired in lua/plugins/lsp.lua (blink provider `angular_inputs`)
**Tags:** angular, typescript, treesitter, ripgrep, navigation, gd, completion, blink, input, output, tag, auto-import, ngmodule, index

## Scope

**`GAF=1` only.** The code is not Freelancer-specific — it would work in any Angular project — but it is gated with the rest of the GAF tooling, because tag completion indexes every `selector:` under the search root and that is wasted work anywhere else. Without the flag nothing here loads: no keymaps, no `:AngularReindex`, and `typescript` keeps blink's `default` source list. Tuned for **inline-template** Angular (`@Component({ template: `...` })`): the `angular` treesitter parser auto-injects into the template backtick string (see [ts-nvim-treesitter](ts-nvim-treesitter.md)), so tag/attribute names under the cursor are read precisely. Projects with external `.component.html` templates still get the `.ts`-side navigation (selectors, `@Input`/`@Output`, routes) but not the in-template reads that need the injected tree.

All lookups are treesitter (to classify what's under the cursor) + `rg --vimgrep` (to find the definition) — no language server. Single hit jumps straight; multiple hits open a Snacks picker.

Lived at `lua/gaf/angular.lua`, then briefly ungated at `lua/angular/`; now back under `lua/gaf/angular/` with the profile gate, since a repo-wide selector index only pays for itself in the webapp.

## Keymaps (buffer-local, on `typescript` buffers)

| Key | Action |
|---|---|
| `gd` | Definition under cursor (Angular-aware, see below); falls back to `Snacks.picker.lsp_definitions()` on plain TS |
| `<leader>cp` | Parent components — files whose template uses this component's selector ("up"/callers) |
| `<leader>cG` | Prompt for a component name (class like `FooComponent`, prefix ok, or selector `app-foo`) → its definition |
| `<leader>cR` | URL/route string under cursor (`/messages/thread/${id}`) → the `path:` line in the routing module that handles it |

`<leader>cR` is owned by this module on typescript buffers; the TS "remove unused" action lives on `<leader>cx` ([lsp-vtsls](lsp-vtsls.md)) precisely to avoid shadowing it.

### What `gd` resolves

- **tag** (`<app-foo>`) → the component's `selector:` definition (picker when several files define the same selector)
- **attribute** (`[size]`, `(click)`, `flDir`) → the `@Input`/`@Output`/signal on the tag's component, else an attribute-selector directive
- **class binding** (`class="x"`, `[class.x]`, `ngClass`) → the `.x` rule in the component's own stylesheet (`styleUrls`), with SCSS `&`-nesting (BEM) suffix matching; offers to create the rule when missing
- **binding expression symbol** (`ButtonSize.SMALL`, `plainVar`) → PascalCase/CONST → a type/enum/class/const under the search root (landing on the member for `Enum.MEMBER`); lowerCamel → a class member in the component file
- **template-local** (`@if (…; as x)`, `@for` var, `@let`, `*ngIf="… as v"`, `#ref`, `<ng-template let-ctx>`) → the binding site (innermost enclosing scope wins); checked before the class-member search

## Inline-template tag completion (blink.cmp)

Typing `<` in an inline template offers every component in the repo (4814 selector definitions over 4723 distinct selectors in the GAF webapp), each labelled with its defining directory as an import-style path (`@freelancer/ui/button`) so the three files that define `app-search` are told apart in the menu. Accepting inserts the **whole element** and makes it resolve (auto-import, below).

- **Paired, always:** the snippet is `<fl-button$1>$0</fl-button>`. The webapp writes 28506 `</fl-x>` closings against 134 self-closing tags, so the self-closing form is never worth offering. `$1` sits at the end of the start tag, right before `>`, where bindings go; `$0` sits between the tags, where content goes.
- **Replaces the `<`:** the item's `textEdit` starts at the column of the `<` the user already typed (`meta.lt_col`), not at blink's keyword start (which begins *after* the bracket) — the same left-extension the binding items use to swallow a typed `[`/`(`.
- **Position test:** a `<` followed only by tag-name characters, with the cursor inside a `template_string` and not inside a quoted attribute value. A space, a `>` or an attribute in between means the name is already written and attribute completion owns the cursor.
- **Trigger:** `<` was added to the source's trigger characters. It also opens a TS generic, which is harmless — the data layer only answers inside an inline template.

**An empty prefix builds nothing, deliberately.** A bare `<` matches the entire index, and the consumer discards it: the source returns `items = {}, is_incomplete_forward = true` so blink comes back the moment a letter narrows it. `template_tag_completions` therefore answers `cb({}, meta)` for an empty prefix **without touching the index** — `meta` keeps its `{ lt_col, prefix }` shape, so the source's guard is unchanged. What that saves: the first `<` typed in any template — including `<div`, which will never want this menu — would otherwise pay the ~0.3–0.6 s repo-wide `rg` index build, and every `<` after it ~1.1 ms to build the 4814-item list plus ~1.1 ms for blink to score it, for a menu 4814 entries wide that is thrown away. Typing one letter (`<f`) builds the index and returns the full list; the second keystroke is a 0.03 ms table read.

### The two indexes

Tag completion can't work the way the attribute lookup does — there is no tag under the cursor yet to `rg` for — so the candidate set comes from repo-wide indexes. Both are **per search root** (the user moves between git worktrees, so two roots can be live in one session), **lazy** (nothing builds at startup; the first lookup that needs one pays for it), and coalesce concurrent callers, so the N keystrokes typed during the first build don't each spawn their own `rg`.

| Index | Holds | Cold | Warm |
|---|---|---|---|
| lua/gaf/angular/selector_index.lua | `selector → { file, lnum }` for every **element** selector — a comma list is split and only dashed bare names survive, so `[attr]`, `.class`, `:not(…)` and native tags are dropped. 4814 definitions, 4723 selectors. | ~0.3–0.6 s (one `rg` for `selector:`) | 0.03 ms |
| lua/gaf/angular/module_index.lua | every `@NgModule`'s `declarations`/`exports`/`imports`, plus `declarer[Class]` (the module that declares it) and `exporters[Class]`. 1983 modules across 1977 files, 3792 declared classes, 1572 exported. | ~0.3–0.6 s (one `rg` for `@NgModule`, then a read + scan of each file) | 0.004 ms |

- The derived blink item list (a directory label per definition, then a sort — ~30 ms over the webapp) is memoized against the index's `revision()` counter, not rebuilt per keystroke. `update_file` patches entry tables in place, so identity can't carry that signal.
- Building the selector index **warms the pre-existing `selector → file` cache** that attribute completion uses, so the first `[` typed inside a freshly completed tag no longer spends an `rg`. An existing entry is never overwritten — that one was resolved against a real cursor context.
- **`BufWritePost *.ts`** re-reads just the written file into both indexes (a line scan / a re-scan, no `rg`). It is a no-op on a root nobody has indexed, so a write can never trigger the repo-wide build, and files outside the root or `*.spec.ts` are ignored so a stray write can't smuggle entries in. Most saved files declare neither a selector nor a module, and the `revision` is then left alone so the memoized item list stays valid.
- **`:AngularReindex`** drops both indexes for the current file's root and rebuilds the selector one, reporting the selector count. The module index is only dropped: nothing needs it until an NgModule-declared tag is completed, and that lookup builds it. Reach for it after a rename or branch switch moved more than write-time patching can follow.

**Why a text scan, not treesitter, for the module index:** over the webapp's `@NgModule` files treesitter parse + traversal costs 350 ms against this scan's 26 ms, and the two agreed on the arrays of all 1982 modules they found. Treesitter would have fit the budget, but a repo-wide index is exactly the thing a user waits on, and nothing here needs a real parse — the three arrays hold bare identifiers, and the only structure that can hide a bracket is a comment or a string (`ui.module.ts` keeps a JSDoc carrying `[attr.disabled]` inside its `imports`), which the scan's lexer steps over. What it gives up is the type system's view of an `imports:` that isn't an array literal; see Limits.

### Auto-import on accept: standalone consumer

An accepted tag only compiles if the component is reachable from the consumer, so `resolve` attaches both edits as `additionalTextEdits` and blink applies them with the tag in one undo block:

1. `import { ButtonComponent } from '@freelancer/ui/button';` — merged into an existing single-line import from the same module, else added as a new line after the last import statement. Skipped when the name is already imported anywhere in the file, or when the target *is* this file. The specifier is the same barrel-preferring `import_spec` the enum import uses.
2. the class in the consumer's own `@Component({ imports: [ … ] })`.

The array edit **follows the array it finds** — one line stays one line, a line per entry gets a line, a trailing comma is matched — so prettier has nothing to say about it. Alphabetical placement is offered **only when the array is already sorted**: the webapp's arrays are sorted about as often as not, and slotting a name into the middle of a hand-ordered list reads as noise in the diff, so an unsorted array gets an append. A missing `imports:` key is created **directly above `template:`** — of the 1299 standalone components in the webapp that declare the key, 1122 (86%) put it immediately before `template`, every one of the 97 without it has a `template` to sit above, and prettier never reorders object keys.

`build_component_edits` wires nothing (and hands back a `reason` the docs popup prints) when the target is NgModule-declared, the consumer is NgModule-declared (the plan path below takes over), the target is this component's own selector, or the cursor isn't in a component template.

### Auto-import on accept: NgModule consumer

When the consumer is `standalone: false` its own decorator has no `imports:` to grow — what has to change is the `imports:` of the NgModule that **declares** it, in a different file. LSP defines `additionalTextEdits` as same-buffer, so `resolve` cannot reach it and only the source's `M:execute` can, after `default_implementation()` has inserted the tag (the user is waiting on that; cross-file work must never be in front of it).

`build_ngmodule_plan` returns a plan and applies nothing — editing a file the user isn't looking at is the caller's decision:

- **Already reachable?** Three ways, all of which make an import redundant noise: the owning module already declares the target, the owning module already imports a module that **exports** it, or it already imports the chosen symbol. The middle check is the one that earns its keep — a consumer that pulls an aggregate like `UiModule` can already see all 147 of its components. Only *direct* exports are indexed, no walk of the module graph, because the aggregates a consumer actually reaches for re-export their contents directly.
- **What gets added:** a standalone target goes in as itself (Angular allows a standalone component in a module's `imports`); an NgModule-declared one can only arrive via a module that exports it.
- **Several exporters** → tie-break in order: the module nearest the target in the directory tree (a component's own feature module is what its author meant to be used; an unrelated module that happens to re-export it is not), then the shortest import specifier (a barrel like `@freelancer/ui` over a deep path to the same thing), then the file path so the answer never depends on `rg`'s ordering. The notification appends `(1 of N modules exporting X)` when there was a choice.
- The loaded **buffer is the authority over the index** for the final check: it may hold an unsaved `imports` the index hasn't seen, and a nil edit then means "already there".

**Save policy** (`apply_plan`): the module file is `bufadd`+`bufload`ed and edited in place. A buffer that was **already modified** holds the user's own unsaved work — writing it would commit changes they never asked to commit — so it is edited and handed back (`changed, left unsaved`). A **clean** one is written, because nothing else will: the file is off screen and the change would be lost to the next `:bd` or checkout. The write is `noautocmd`, so format-on-save can't bury a two-line wiring change in a whole-file reformat. Either way exactly **one** INFO notification, naming the symbol, the module, the file and whether it was saved — and it reports whether the write *happened*, not whether it was attempted. A `none` plan notifies nothing: the docs popup already explained that case.

`vim.g.angular_auto_wire` is read at accept time, so it can be flipped mid-session:

| Value | Effect |
|---|---|
| `"all"` (default — and anything unrecognised) | also edit the owning `@NgModule`, saving that file when its buffer was clean |
| `"standalone"` | this buffer's edits only; never a second file |
| `false` | same as `"standalone"` |

Unrecognised values fall back to `"all"` because the NgModule case is the majority: 3837 of the webapp's 5209 components are `standalone: false`.

### The docs popup, and the one line it will not promise

The popup for a focused tag item is built in `resolve` (so the parse is paid ~once per keystroke, not 4814 times per menu) and shows the class, its import specifier, `standalone` vs `module-declared`, the input count, the file, and a `→` line saying what accepting does to the buffer: "imports `X` … and lists it in `imports: [ ]`", "already imported and in `imports: [ ]` — nothing to add", "no import path found, import it by hand", or the reason nothing will be wired.

For the NgModule case that line is deliberately **static** — "on accept `X` (or a module exporting it) goes into the owning `@NgModule`" — rather than naming the module and saying whether it is already reachable. An accurate line needs the module index, a ~0.3–0.6 s build, inside `resolve`; this config sets `completion.accept.resolve_timeout_ms = 500` ([cmp-blink](cmp-blink.md)), so on accept blink would hit the timeout, drop the resolved item, and take the standalone path's `additionalTextEdits` with it. The popup promises the attempt; the notification reports what came of it.

**Limits:** no type checking (still not a language server) — a selector is offered because it exists, not because the component would accept the bindings around it. An `imports:` whose value is not an array literal (a spread, a shared const) reads as *empty* to the module index, and the edit builder refuses to rewrite it — a second `imports` key would be invalid TS — so the plan comes back `none` with that reason. A multi-line `import { … }` block from the target's module is not merged into; a new import line is added instead (single-line imports merge cleanly). A `<` used as a comparison inside a binding expression (`[x]="a <b"`) still passes the tag-name test — harmless, since nothing there fuzzy-matches a selector. `standalone` is kept as a tri-state: an absent key records as `nil`, not `true`, because Angular 19 reads it as standalone but an Angular 14 component meant NgModule — so the wiring asks `standalone ~= false`, not `== true`.

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
- `.component_inputs(cb)` → resolves the component tag under the cursor to its member list and calls `cb(inputs, { tag, file })`, or `cb(nil)` when the cursor isn't inside a component tag. Async only on a selector cache miss (one `rg`). Consumed by the blink source in lua/gaf/angular/inputs_source.lua.
- `.resolve_type(type, cb)` → `cb({ kind="enum", name, file, spec, members })` or `cb({ kind="union", name, file, spec, values })` for an exported enum or string/number-literal `type` alias; else `cb(nil)`. Cached per normalized name (handles nullable). Drives value completion.
- `.resolve_enum(type, cb)` → the enum-only view of `resolve_type` (for `Enum.` member completion + attr seeding).
- `.template_enum_members(cb)` → `cb(members, enumName, enumInfo)` when the cursor is inside a template right after `Enum.` and `Enum` resolves to an exported enum; else `cb(nil)`. Drives enum-member completion.
- `.template_value_completions(cb)` → `cb(spec, meta)` when the cursor is inside a component input's value and its type is completable: `spec = { kind = "enum", enum, en }` or `{ kind = "union", values, is_binding }`; else `cb(nil)`. Handles nullable enums (`Enum | null`) and string/number-literal unions.
- `.build_import_edit(bufnr, name, spec, deffile)` → an LSP TextEdit importing `name` from `spec` into `bufnr`, or `nil` if already imported / defined there / spec unknown.
- `.build_enum_field_edit(bufnr, name)` → an LSP TextEdit adding `name = name;` as the first field of the component class enclosing the cursor, or `nil` if already present / no class found.
- `.template_tag_completions(cb)` → `cb(items, { lt_col, prefix })` with `items = { { selector, file, dir }, … }` for every element selector under the search root; `cb({}, meta)` — no index build — when `prefix` is empty; `cb(nil)` when the cursor isn't in tag-name position. `lt_col` is the 0-indexed column of the `<`.
- `.component_info(file)` → `{ class, standalone, spec, selector, inputs }` (`inputs` is a count, `standalone` the tri-state) for the first `@Component` in `file`, or `nil`. Cached per file+mtime, misses included.
- `.consumer_info(bufnr)` → `{ class, standalone, decorator, imports_range }` for the component whose inline template holds the cursor, or `nil`. `decorator`/`imports_range` are LSP ranges; `styles:` is correctly not a template.
- `.build_imports_array_edit(bufnr, name)` → an LSP TextEdit adding `name` to the enclosing `@Component`'s `imports` array (creating the key above `template:` when absent), or `nil` when the consumer is NgModule-declared / `name` is already listed / `imports` isn't an array literal / no component at the cursor.
- `.build_component_edits(bufnr, target_file)` → `edits, info` — the `additionalTextEdits` that make `target_file`'s selector resolve here, and `component_info(target_file)` plus a `reason` string when `edits` is empty.
- `.modules_exporting(class, cb)` → `cb({ { module_class, file, spec }, … })`, every NgModule directly exporting `class`.
- `.module_for_component(class, cb)` → `cb({ module_class, file })` for the NgModule declaring `class`, else `cb(nil)`.
- `.build_ngmodule_plan(bufnr, target_file, cb)` → `cb({ kind = "none", reason })` or `cb({ kind = "module", file, module_class, name, spec, edits, summary })`. `edits` are TextEdits against `file`, **not** `bufnr`, built against a loaded-and-unmodified buffer for it; applying and saving is the caller's call.
- `.reindex()` (also `:AngularReindex`) — drop both indexes for the current file's root and rebuild the selector one.

## Notes

- **Search root** for `rg`: nearest `webapp/src` ancestor, else `webapp`, else `src`, else cwd — narrows to the Angular source tree without a config knob. Both repo-wide indexes are keyed on it, so a second worktree gets its own.
- **Route walk** (`<leader>cR`) descends from `src/app/app-routing.module.ts`, crossing `loadChildren` lazy boundaries into `*-routing.module.ts` siblings and `RouterModule.forChild(...)` arrays; `${…}` interpolations match `:param` segments. Best-effort fallback to the deepest match / wildcard for `matcher:`/`redirectTo` routes.
- Reads routing files off disk (`vim.fn.readfile` + `get_string_parser`), not through buffers, so it works from any file in the tree and across git worktrees.

## Links

- Tag jumping / rename (separate module): [editor-tagmatch](editor-tagmatch.md)
- Class rename shares the styleUrls/BEM logic: [config-rename](config-rename.md)
- Template injection that powers in-template reads: [ts-nvim-treesitter](ts-nvim-treesitter.md)
- Related-file picker for `.ts` ↔ `.scss`/`.spec` etc.: [workflow-other](workflow-other.md)
- TS source-action keys: [lsp-vtsls](lsp-vtsls.md)
