# Inter-service type inference

Why editor completion and type checking stop working the moment a call crosses a
service boundary, and what this repo can do about it.

Everything below was verified against **mypy 1.7.1** — the version pinned in
`lib/docker/lint/Dockerfile.mypy`, i.e. the version `arc lint` actually runs —
and against **basedpyright**, the editor language server.

---

## The short version

The precise type of every thrift call already exists in this repo, in
`gaf_thrift-stubs/`. Exactly one function discards it: `thrift_wrapper`, in
`libgafthrift/libgafthrift/__init__.py`. Teaching a type checker one rule about
that function restores signatures for roughly 2,600 call sites.

---

## What breaks

Take a normal midlayer call:

```python
projects = self.conns.projects_dao.projects_get(header, perspective, filter, projection)
```

For an editor to complete `projects_get`, check its arguments, or jump to its
definition, it has to answer *"what is `self.conns.projects_dao`?"* by reading
source. It never runs the program.

`conns.projects_dao` is a `thrift_wrapper` (`projects_mid/api.py:7455`). Open
that class and search for `projects_get`. It is not there. No thrift method is.
Instead:

```python
def __getattr__(self, name):
    if hasattr(self.client, name):
        return partial(self.__call, name)
    else:
        raise AttributeError()
```

`__getattr__` is Python's catch-all: *"if someone asks for an attribute I don't
have, run this instead."* At runtime it forwards to the real generated client,
so the call works. Statically it accepts **any** string, so a checker cannot
enumerate the valid names, their arguments, or their return types. The only
sound answer it can give is `Any`.

`Any` means *"I know nothing, permit everything."* Hence no completion, no typo
detection, no go-to-definition, no warning when the wrong struct is passed.

### This is the layer boundary, and it is every boundary

The same wrapper backs all three hops:

| hop | example | call sites |
|---|---|---|
| `rest` -> midlayer | `flask.current_app.conns.projects.project_bids_get(...)` | 529 |
| midlayer -> dao | `self.conns.projects_dao.projects_count(...)` | \* |
| midlayer -> midlayer | `self.conns.users_mid.users_get(...)` | \* |

\* 2,062 combined across the midlayers and daos.

### The evidence that this is the pain

There are **503** `# type: ignore` comments in the repo, 502 of them bare (no
error code, so they suppress everything on the line, forever). They do not
cluster in the old unannotated files. They cluster in the *newest, best
annotated* ones — `contests.py` 87, `quotations.py` 77, `service_offerings.py`
43 — because those are the files where typed code meets the untyped proxy:

```python
def contest_create(self, header: Header, contest: ContestCreateArguments) -> Contest:
    return self.conns.gaf.contest_create(header, contest)  # type: ignore
```

Six accessors in `rest/` are annotated `-> DummyWrapper`, which is the
**test-only** in-memory wrapper from `libgafthrift/dummy_wrapper.py`. The runtime
object is a `thrift_wrapper`. The annotation is both wrong and useless —
`DummyWrapper` has the same `__getattr__`, so it yields `Any` anyway.

---

## What is not broken

`gaf_thrift-stubs/` is complete and good: 223 `.pyi` files, 3,320 classes, zero
`Any`, covering 100% of the `gaf_thrift.*` modules this repo imports. Structs
carry per-field optionality, enums are real `Enum` subclasses, and both `Iface`
and `Client` are fully annotated:

```python
class Client(Iface, healthcheck_api.Client):
    def project_bids_get(
        self, header: header_ttypes.Header, filter: ProjectBidsFilter,
        projection: ProjectBidsProjection) -> ProjectBidsGetResult: ...
```

These resolve today — basedpyright finds them via `extraPaths`, and `arc lint`'s
mypy wrapper bind-mounts them at `/lib/python/gaf_thrift` with
`MYPYPATH=/lib/python/` (`lib/bin/mypy:22-27`).

So the information exists and is reachable. Nothing connects *"this wrapper
wraps the projects dao api"* to *"here are the projects dao api's methods."*

---

## The missing link

The connection is recoverable, because every construction site names the
service:

```python
self.projects_dao = libgafthrift.thrift_wrapper(
    config.get("projects-dao-thrift", "host"),
    common_ttypes.ThriftPorts.PROJECTS_DAO,
    gaf_thrift.projects.dao.api,          # <- the service
    timeout=...,
)
```

and the wrapper internally does `client_class.Client(...)`. So:

> `thrift_wrapper(host, port, M)` behaves exactly like `M.Client`

Always true, purely mechanical, and nowhere written down in a form a checker can
read.

## Writing it down

`libgafthrift/libgafthrift/__init__.pyi` declares it:

```python
class _ThriftApi(Protocol[_I]):
    """Structural type of a generated ``gaf_thrift.<service>.api`` module."""
    Client: type[_I]

def thrift_wrapper(host: str, port: int | Enum, client_class: _ThriftApi[_I],
                   retries: int = ..., timeout: float = ..., ...) -> _I: ...
```

In words: *given a module that has a `Client` of some type `_I`, return an
`_I`.* `_I` is a placeholder resolved per call — pass `gaf_thrift.projects.api`
and you get the projects client; pass `gaf_thrift.users.dao.api` and you get the
users dao client. One declaration, correct for every service and every layer.

No runtime behaviour changes. No call site changes.

### Result

```
Type of "c.projects_dao"      is "Client"
Type of "c.users_mid.users_get" is
  "(header: Header, filter: UsersFilter, projection: UsersProjection) -> UsersGetResult"
error: Cannot access attribute "projects_count_TYPO" for class "Client"
```

Measured against `projects_mid/api.py`, `projects_mid/contests.py` and
`restutils/flask_acl.py`: **97 errors before, 97 after, 0 new, 0 silenced.** The
stub adds capability without changing any existing diagnostic.

---

## Design notes

**Why `thrift_wrapper` is declared as a function.** The natural form is a
generic class whose `__new__` returns the TypeVar. Pyright accepts it; mypy
rejects it outright:

```
error: "__new__" must return a class instance (got "_I")  [misc]
```

Since mypy gates `arc lint`, the class form is unusable. The function form is
accepted by both. Nothing in the repo subclasses `thrift_wrapper` or calls
`isinstance` against it, so nothing depends on it being a class.

**Why the stub lives inside the package.** A `.pyi` placed in an external
`stubPath` directory hides the package's own submodules — `from libgafthrift
import enterprise_utils` stops resolving, which then silently degrades unrelated
types. Placing it next to `__init__.py` keeps every sibling module resolving
normally.

**Why not a full generated stub tree.** `basedpyright --createstub libgafthrift`
emits 72 files, and they look like an improvement — error count drops from 97 to
77. That drop is fake. The generator writes inferred type names *without
importing them*: `enterprise_utils.pyi` returns `-> DirectoryFilter` but never
imports `DirectoryFilter`, so the name is undefined, the type becomes unknown,
and 20 legitimate warnings vanish. Stub only the one module that needs it.

**Regeneration hazard.** A `.pyi` shadows its module, so anything added to
`__init__.py` is invisible until the stub is regenerated. Regenerated output also
needs its imports repaired (`Any`, `Self`, `gaf_thrift`, `_RetAddress`, and
`from collections import Iterable` -> `collections.abc`) before mypy accepts it.

---

## The midlayers need `self.conns` declared

The stub types `Connections` itself, but inside a midlayer every call still went
through `self.conns`, and that was `Unknown`:

```python
class UserHandler(..., gaf_thrift.users.api.Iface, metaclass=TracingMetaClass):
    def __init__(self, connections):     # unannotated
        self.conns = connections          # -> Unknown
```

So `users_mid/api.py:606` gave `users: Unknown`:

```python
users = self.conns.users_dao.users_get(header, ..., dao_projection)
```

Each of these modules defines its own `Connections` class further down the same
file, so a forward reference is all that is needed:

```python
def __init__(self, connections: "Connections"):
```

That one annotation per service covers 767 `self.conns.*` sites (users_mid 348,
projects_mid 260, messages_mid 159). The line above now reads:

```
self.conns      -> Connections
conns.users_dao -> Client
users_get       -> (header: Header, filter: DAOUsersFilter,
                    projection: DAOUsersProjection) -> Dict[int, User]
users           -> Dict[int, User]
```

Cost across the midlayers: +11 errors and +101 warnings, and the 11 errors are
all genuine unchecked-optional bugs of the form

```
error: Operator "in" not supported for types "int" and "List[int] | None"
```

**The leaf daos are deliberately excluded.** `projects_dao`, `users_dao` and
`messages_dao` make no outbound RPC at all — their `Connections` holds MySQL
handles and memcache, not thrift clients — so annotating them buys nothing. It
also costs a great deal: the in-house dict cursor from `libgafthrift.dao` infers
imprecisely, so every `cursor.fetchone()["col"]` starts reporting `No overloads
for "__getitem__"`. Annotating `projects_dao` alone added 92 such false errors,
which is why the handler list stops at the midlayers plus `pii_store` (the one
bottom-layer service that does hold thrift clients).

### The mixins

Annotating the handler is not enough on its own. Most of a midlayer's thrift
calls live in mixins — `ContestMixin` (71 uses), `GroupsMixin` (37),
`QuotationMixin` (25), `SupportMixin` (22), `TasksMixin` (18) and eleven more,
242 uses in total. They have no `__init__`; `conns` is set by the handler class
they are mixed into, and pyright does not propagate an attribute from a sibling
base. Each needs a class-level declaration:

```python
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from users_mid.api import Connections


class GroupsMixin(object):
    # Set by the handler class this mixin is mixed into; declared here so
    # self.conns.<service> resolves to the generated thrift Client.
    conns: "Connections"
```

The guard is required, not stylistic: `api.py` imports these modules, so
importing `Connections` back at runtime would be circular. Under
`TYPE_CHECKING` the import never executes.

Cost across the six busiest mixin files: 7 errors → 10, and the three new ones
are real (`set[int | None]` assigned into `set[int]`, a `dict[int | None, ...]`
into `dict[int, int]`, an `int` returned where `MinimalMessageSourceType | None`
is declared).

---

## A second, unrelated cause: werkzeug's `LocalProxy`

Most of the noise in `rest/api` had nothing to do with thrift. `flask.current_app`,
`flask.g` and `flask.request` are all `werkzeug.local.LocalProxy` instances, and
in werkzeug 0.11 the proxy's attribute hook is written as:

```python
def __getattr__(self, name):
    if name == "__members__":
        return dir(self._get_current_object())      # -> list[str]
    return getattr(self._get_current_object(), name)    # -> Any
```

Pyright unions both branches into `list[str] | Any`, then reports every
attribute access against the `list[str]` arm:

```
contests_api.py:2352 - Cannot access attribute "contests" for class "list[str]"
```

That single inference produced **1,804 of the 2,383 diagnostics in `rest/api`** —
76% of the total, every one of them spurious.

Narrowing the return to `Any` (which is what the proxy actually yields for any
name other than the `__members__` special case) takes `rest/api` from **263
errors / 2,120 warnings to 24 errors / 316 warnings**. 2,044 diagnostics removed,
one added — and that one is real: `challenges_api.py:373` returns a 1-tuple
(`return (json_response(...),)`, note the trailing comma) from a function
annotated `-> flask.Response`. Flask 0.11 pads short tuples, so it works by
accident.

The stub is installed into the api311 virtualenv's `site-packages/werkzeug/`,
not the repo. Git never sees it, and neither does `arc lint` — its mypy runs in a
separate Docker image with its own dependency set. Only the editor reads it. A
`pip install`/reinstall of werkzeug removes it; rerun `:GafTypingApply`.

This is worth understanding as a separate problem from the thrift one. Even with
every RPC perfectly typed, the `rest/` layer would still have been drowning in
these. Fixing it does not make `current_app.conns` typed — it makes it honestly
`Any` again, instead of confidently wrong.

---

## The `rest/` layer needs one extra step

The stub alone does not help `rest/`, for an unrelated reason: Flask is pinned at
`0.11` (`rest/setup.py:20`) and is untyped, so `flask.current_app` is already
`Any` before you reach `.conns`. The chain is dead one link earlier.

Two changes cover it.

**The six accessors**, whose annotations are wrong anyway:

```python
def projects_thrift() -> ProjectsThriftClient:
    """Return a projects thrift client."""
    return flask.current_app.conns.projects
```

Returning `Any` into a declared type is allowed, so this is a legal, one-line
bridge across the untyped proxy. Every caller of the accessor is then typed.

**Declaring `conns` on `current_app`**, which covers the ~529 call sites that
do not go through an accessor. `conns` is not a Flask attribute — it is
monkey-patched on at `rest/api/server.py:229` — so a stub for `flask.globals`
supplies it:

```python
class _GafFlaskApp:
    conns: Connections
    def __getattr__(self, name: str) -> Any: ...

current_app: _GafFlaskApp
```

The `__getattr__` fallback keeps `config`, `logger`, `auth_common` and the rest
as `Any`, so exactly one name is narrowed. `request`, `session` and `g` stay
`Any` on purpose — `flask.g` is used as a free-form attribute bag throughout.

Cost: 12 new diagnostics across `rest/api` (1 error, 11 warnings), all genuine
findings `Any` had been hiding — including `superuser_api.py:101` returning an
`int` from a function annotated `-> Response`.

**Staleness caveat.** Typing `conns` means any thrift method newer than the
locally generated `gaf_thrift-stubs/` reads as an unknown attribute. One such
case exists today: `contest_rubric_submission_upsert` is implemented at
`projects_mid/contests.py:875` and called from `contests_api.py:2474`, but is in
neither the stubs nor the venv's `gaf_thrift` (`.thrifthash` is from
2026-06-17). Regenerating the thrift definitions clears it, and
`reportAttributeAccessIssue` is already set to "warning", so these surface as
warnings rather than errors.

**Watch the aliasing.** `rest/api/server.py:82-90` and `:29-37` assign one
wrapper to several attributes in a chain. `conns.ai` is an alias of the **users**
wrapper, not `gaf_thrift.ai.api` — the `ai_*` methods are declared on
`gaf_thrift-stubs/users/api.pyi`. Annotating `ai_thrift()` as an ai client would
be a plausible-looking lie. Same for `contests`, `quotations`,
`service_offerings`, `timelines`, `challenges` (all the projects wrapper) and
`support`, `groups`, `feed`, `posts`, `tasks`, `external_credentials` (all the
users wrapper).

---

## Coverage

Every cross-service edge in the monolith, verified with `reveal_type` against
the real modules (0 errors, 0 warnings):

| edge | example | resolves to |
|---|---|---|
| rest → mid (accessor) | `projects_thrift().project_bids_get` | `(header, filter, projection) -> ProjectBidsGetResult` |
| rest → mid (`current_app`) | `current_app.conns.contests.contest_create` | `(header, contest) -> Contest` |
| rest `Connections` | `r.users.users_get` | `(header, filter, projection) -> UsersGetResult` |
| mid → own dao | `pm.projects_dao.projects_count` | `(header, perspective, filter) -> int` |
| mid → own dao | `um.users_dao.users_get` | `(...) -> Dict[int, User]` |
| mid → own dao | `mm.messages_dao.threads_get` | `(...) -> List[Thread]` |
| mid → mid | `pm.users_mid.users_get` | `(...) -> UsersGetResult` |
| mid → mid | `pm.messages_mid.threads_get` | `(...) -> ThreadsGetResult` |
| mid → other service's dao | `um.projects_dao.jobs_get` | `(...) -> List[Job]` |
| mid → PHP monolith | `pm.gaf.contest_create` | `(header, contest) -> Contest` |
| pii_store → dao | `p.users_dao.users_get` | `(...) -> Dict[int, User]` |
| pii_store → mid | `p.users_mid.users_get` | `(...) -> UsersGetResult` |
| mixin (projects_mid) | `cm.conns.gaf.contest_create` | `(header, contest) -> Contest` |
| mixin (users_mid) | `gm.conns.users_dao.users_get` | `(...) -> Dict[int, User]` |
| mixin (messages_mid) | `km.conns.users_dao.users_get` | `(...) -> Dict[int, User]` |

Not covered, by design: the leaf daos' internals (raw SQL over an untyped dict
cursor — see above), and any service not checked out locally, such as
memberships, where only the thrift contract exists.

## Installing

Everything is driven by `~/.config/nvim/gaf-typing/`, which is versioned with
the Neovim config, so there is nothing to fetch or build. The patch is fully
idempotent — running it when it is already applied is a no-op.

### From Neovim

| command | effect |
|---|---|
| `:GafTypingApply` / `<leader>lT` | install everything; prompts first |
| `:GafTypingEnsure` | install **only if** something is missing; silent when already applied |
| `:GafTypingCheck` | report what is installed, changing nothing |
| `:GafTypingRevert` | undo all of it |

`:GafTypingApply` and `:GafTypingRevert` prompt with a summary of what will
change and default to Cancel. The bang forms — `:GafTypingApply!`,
`:GafTypingRevert!`, `:GafTypingEnsure!` — skip the prompt.

`:GafTypingEnsure` is the one to reach for after a `git reset`: it checks first
and says nothing when there is nothing to do. To have it run automatically on
entering an api-repo python buffer, add to your config:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(ev)
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if vim.startswith(name, vim.fn.expand("~/freelancer-dev/api")) then
      require("gaf.typing").ensure(true)   -- true = no prompt
    end
  end,
})
```

It is deliberately not enabled by default: it writes to 27 tracked files, and
that should be a decision you make rather than a side effect of opening a file.

### From the shell

```sh
python3 ~/.config/nvim/gaf-typing/apply.py            # install
python3 ~/.config/nvim/gaf-typing/apply.py --check    # report; exit 1 if incomplete
python3 ~/.config/nvim/gaf-typing/apply.py --revert   # undo
```

`--api PATH` and `--venv PATH` override the defaults
(`~/freelancer-dev/api`, `~/.pyenv/versions/api311`), or set `GAF_API_ROOT` /
`GAF_API_VENV`. `--check` exits non-zero when anything is missing, so it works
in a shell prompt or a pre-commit hook.

### Prerequisites

- the `api311` pyenv virtualenv, with the ten services installed editable —
  this is what `lua/gaf/lsp.lua` already points basedpyright at
- `gaf_thrift-stubs/` present at the repo root (gitignored and generated;
  `./run.sh` regenerates it from the thrift repo)

Both are the same things basedpyright already needs, so if completion works at
all, the prerequisites are met. `apply.py` skips the venv stubs with a warning
rather than failing if the virtualenv is missing.

### What survives what

| event | effect |
|---|---|
| `git reset --hard` | reverts the 27 tracked edits; stubs survive → `:GafTypingEnsure` |
| `git clean -fdx` | also removes the in-repo stub and `docs/` → `:GafTypingApply` |
| `pip install` of flask/werkzeug | removes those two venv stubs → `:GafTypingApply` |
| regenerating `gaf_thrift-stubs` | no effect on the patch |
| editing `libgafthrift/__init__.py` | stub goes stale; regenerate (see the stub's header) |

The in-repo stub is added to `.git/info/exclude` rather than `.gitignore`,
because editing `.gitignore` would itself show up as a tracked change.

---

## If this were to be adopted properly

The stub is a local workaround. The equivalent committed change is a small typed
factory beside `thrift_wrapper`, which needs no stub and no shadowing:

```python
def thrift_client(host, port, api_module, retries=0, timeout=8000.0, ...):
    # type: (str, Union[int, Enum], ThriftApi[_I], ...) -> _I
    """Return a thrift_wrapper typed as api_module's generated Client."""
    return cast("_I", thrift_wrapper(host, port, api_module, ...))
```

`libgafthrift` still ships a `Dockerfile-py2` and `common.groovy:998` still runs
`./run.sh test <lib> --py2 --CI`, so it must stay Python-2 parseable — hence the
type comment, and hence keeping the `Protocol` in a stub-only module that no
interpreter ever loads. `typing` is already a declared py2 dependency
(`libgafthrift/setup.py:58`).

Migrating the 40 construction sites to `thrift_client` would type all 2,062
midlayer and dao call sites permanently, for the whole team, with no shadowing
and no regeneration hazard.

Worth doing alongside it:

- Declare `conns` on the mixins. `QuotationMixin`, `ContestMixin`,
  `ChallengeMixin`, `ServiceOfferingMixin` and `TimelineMixin` all use
  `self.conns` without declaring it, which is why `contests.py` and
  `quotations.py` carry 164 `# type: ignore` between them.
- Make `restutils.JsonToThrift` (`restutils/__init__.py:527`) generic, so
  `JsonToThrift(AiProofreadRequest)(json_data)` stops returning `Any` and the
  inbound request boundary is typed too.
- Add `libgafthrift.*`, `restutils.*` and `pii_store.*` to the per-module
  `ignore_missing_imports=false` list in `mypy.ini`; they currently degrade to
  `Any`, which undercuts everything above.
- Turn on `warn_unused_ignores` once the above lands, to find and delete the now
  dead `# type: ignore` comments automatically.
