# snippets-dir
> Local VS Code-format snippet pack consumed by LuaSnip and edited by scissors.

**Local spec:** snippets/
**Tags:** snippets, gaf, php, ruby, typescript

## Scope

`~/.config/nvim/snippets/` is a self-contained VS Code snippet "extension". It is loaded by LuaSnip's `from_vscode` loader (see [[cmp-luasnip]]) and edited in place by `scissors.nvim` (see [[editor-scissors]]). Each filetype has one JSON file; snippets are written once and instantly available in both engines.

## Structure

```
snippets/
├── package.json   manifest mapping language -> json file
├── php.json       PHP + GAF Phoenix (Controller/Handler/Repo/DTO/Enum/Test) + PHPDoc
├── ruby.json      Rails controllers, models, ERB form helpers, RSpec, etc.
├── eruby.json     ERB tag wrappers and form helpers
└── typescript.json GAF Angular components, RxJS, signals, etc.
```

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

## Links

- VS Code snippet syntax: https://code.visualstudio.com/docs/editor/userdefinedsnippets
- scissors.nvim: https://github.com/chrisgrieser/nvim-scissors

## Notes

- Files are mtime-watched by LuaSnip's lazy_load — saving via scissors causes a reload on next BufEnter of that filetype.
- Keep `prefix` values short and namespaced (`fl-` for GAF-specific, `doc*` for PHPDoc) to avoid menu clutter.
- Lua-DSL snippets are NOT used here — everything is JSON so scissors can round-trip edit them.
