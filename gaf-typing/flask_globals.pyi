"""Editor-only type stub for ``flask.globals`` (Flask 0.11).

Purpose
-------
Flask 0.11 predates type annotations, so ``flask.current_app`` is an untyped
``LocalProxy`` and ``flask.current_app.conns`` resolves to ``Any``. That kills
inference for the ~529 ``current_app.conns.<service>.<method>(...)`` call sites
in ``rest/`` before the thrift layer is even reached -- the chain is already
dead one link earlier.

``conns`` is not a Flask attribute at all: it is monkey-patched on at
``rest/api/server.py:229`` (``app.conns = Connections(app)``). Declaring it here
is what connects ``current_app`` to the real ``Connections`` class, whose
attributes are in turn typed by the libgafthrift stub.

The ``__getattr__`` fallback keeps every other attribute (``config``,
``logger``, ``auth_common``, ``identity``, ...) as ``Any``, so this narrows
exactly one name and changes nothing else. ``request``, ``session`` and ``g``
stay ``Any`` deliberately -- ``flask.g`` in particular is used as a free-form
attribute bag throughout the repo.

Measured over ``rest/api``: 529 call sites gain real signatures, at the cost of
12 new diagnostics (1 error, 11 warnings), all of them genuine findings that
``Any`` had been hiding.

Known limitation
----------------
Typing ``conns`` means a thrift method newer than the locally generated
``gaf_thrift-stubs/`` reads as an unknown attribute. There is one such case
today: ``contest_rubric_submission_upsert`` is implemented at
``projects_mid/contests.py:875`` and called from ``contests_api.py:2474``, but is
absent from both the stubs and the venv's ``gaf_thrift`` (``.thrifthash`` is from
2026-06-17). Regenerating the thrift definitions clears it. Because
``reportAttributeAccessIssue`` is set to "warning" in lua/plugins/lsp.lua, stale
methods surface as warnings rather than errors.

Note this file imports ``api.server`` -- the stub depends on the repo being on
the language server's path, which it is via the extraPaths in lua/gaf/lsp.lua.
Opening an unrelated project with this same interpreter leaves ``conns``
unresolved, which is harmless.

Scope
-----
Installed into the api311 virtualenv's site-packages, NOT the repo. Git never
sees it, and neither does ``arc lint`` -- its mypy runs in a separate Docker
image with its own dependencies. Only the editor language server reads it.
A ``pip install``/reinstall of Flask removes it; rerun :GafTypingApply.

Managed by ~/.config/nvim/gaf-typing/. See docs/inter-service-typing.md.
"""

from typing import TYPE_CHECKING, Any

from werkzeug.local import LocalStack

if TYPE_CHECKING:
    from api.server import Connections

class _GafFlaskApp:
    """``flask.current_app``, including attributes bolted on at runtime."""

    conns: Connections
    def __getattr__(self, name: str) -> Any: ...

_request_ctx_stack: LocalStack
_app_ctx_stack: LocalStack
current_app: _GafFlaskApp
request: Any
session: Any
g: Any
