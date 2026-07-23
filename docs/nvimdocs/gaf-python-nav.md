# gaf-python-nav

> Cross-service `gd` for the api monorepo — rest ↔ midlayer ↔ dao thrift navigation by name.

**Local file:** lua/gaf/python_nav.lua
**Tags:** gaf freelancer python api thrift navigation gd basedpyright snacks

## Scope

Services in `~/freelancer-dev/api` talk thrift. Call sites go through dynamic
proxies — `libgafthrift.thrift_wrapper` (`libgafthrift/__init__.py`),
`DummyWrapper` (`dummy_wrapper.py`), `grpc_wrapper.py` — all dispatching via
`__getattr__`, so plain LSP definition dead-ends in the proxy or in a
generated `gaf_thrift-stubs/*.pyi` Client and never reaches the midlayer/dao
handler. Names bridge the gap: every handler implements the generated `Iface`
with the exact thrift method name.

Same idiom as the Angular template `gd` in `lua/angular/`: buffer-local `gd`
shadows the global snacks `gd`, only on python buffers under the api repo,
wired from `gaf/init.lua` → `M.setup()` (GAF-gated).

## Behaviour

- **`gd` on a call site** — tries LSP definition first. Trustworthy real
  target → native `Snacks.picker.lsp_definitions()`. Stub/proxy/garbage
  target → workspace-symbol exact-name lookup, ranked, then jump or picker.
- **`gd` on your own `def` line** — reverse direction: grep picker of every
  `.name(` call site across all services (rest endpoints, other midlayers,
  tests).

## Resolution details

- **Dead ends**: any `.pyi`, plus the three proxy files above.
- **Garbage-target guard**: on an Unknown-typed chain (everything reached via
  untyped Flask `current_app`), pyright anchors "definition" to whatever is
  nearby — e.g. the enclosing call's function when the cursor word is inside
  a kwarg (`json_response(result=conns.messages.X(...))` resolved to
  `json_response`). A target only counts if its line literally contains the
  cursor word.
- **Ranking** (ambiguity handling): `*_mid/` handler (1) > `*_dao/` (2) >
  other (3) > tests (4). The call site's own attribute is a soft hint —
  `conns.projects_dao.foo(` boosts paths containing `projects_dao` by 0.5, so
  dao vs midlayer twins disambiguate. Unique best rank jumps straight;
  genuine ties open a picker.
- **Redraw**: jumps run inside `vim.schedule` + `redraw` — async LSP
  callbacks otherwise leave the old buffer on screen until the next keystroke.
- **Jumps are plain `:edit` + cursor, picker items plain file items.** Never
  hand snacks an `item.loc` (raw LSP location) — snacks then expects
  `item.encoding` and every preview/move errors `invalid encoding`, freezing
  the picker. Same reason jumps avoid `vim.lsp.util.show_document`.

## Limits — what name-based nav can't do

- **Return types don't flow across the RPC boundary.** In rest,
  `conns.projects.projects_search(...)` is `Unknown` — the chain starts at
  untyped Flask (`current_app`) and dies at `thrift_wrapper.__getattr__`.
  Completion/hover on the *result* object therefore doesn't work in rest.
  Config-only fixes don't reach this; the real fix is tiny repo annotations
  (e.g. `def projects_thrift() -> projects_api.Client`) or typed `Connections`
  attrs — one line per service, also improves PyCharm/mypy for everyone.
  Until then: `gd` into the handler and read its signature/stub types there.
- Methods called only bare (`word(`) in the same service are left to plain
  LSP (correct already).

## Verified

- rest `messages_api.py` `conns.messages.comment_feed_create(` → `gd` →
  `messages_midlayer/messages_mid/api.py:1702 def comment_feed_create` (exact).
- `gd` on that def line → "Callers of comment_feed_create" picker, 14 hits
  (rest endpoint + tests).

## Links

- [gaf-lsp](gaf-lsp.md) — basedpyright monorepo wiring this rides on
- [editor-angular](editor-angular.md) — the template-aware `gd` this mirrors
- [gaf-overview](gaf-overview.md) — GAF profile bootstrap

## Notes

- Workspace symbols only cover the single basedpyright workspace — works
  because root_markers force one server rooted at the repo top ([gaf-lsp](gaf-lsp.md)).
- If a thrift method lands in the wrong service, the name is duplicated across
  Ifaces — use the picker entry; ranking hint only helps when the call-site
  attr names the service.
