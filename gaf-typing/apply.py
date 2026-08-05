#!/usr/bin/env python3
"""Reinstall the local inter-service typing patch into ~/freelancer-dev/api.

The api monolith loses all type information at ``libgafthrift.thrift_wrapper``,
whose ``__getattr__`` turns every RPC into ``functools.partial`` -> ``Any``.
This script restores two things that give those calls real thrift signatures:

  1. ``libgafthrift/libgafthrift/__init__.pyi`` -- a type stub teaching the
     checkers that ``thrift_wrapper(host, port, M)`` behaves like ``M.Client``.
     Covers midlayer->dao and midlayer->midlayer (~2000 call sites).
     Untracked, so ``git reset`` leaves it alone; ``git clean -x`` removes it.

  2. Return annotations on the six ``rest/`` thrift accessors, which currently
     claim to return ``DummyWrapper`` -- the test-only class. Tracked edits, so
     ``git reset --hard`` reverts them and this script puts them back.

  3. Two stubs in the api311 virtualenv's site-packages, so neither git nor
     arc lint ever sees them:

     - ``werkzeug/local.pyi`` narrows ``LocalProxy.__getattr__`` from
       ``list[str] | Any`` to ``Any``. That one inference caused 1804 of 2383
       spurious diagnostics in ``rest/api``, since current_app / g / request
       are all LocalProxy.
     - ``flask/globals.pyi`` declares ``current_app.conns``, which Flask 0.11
       cannot know about (it is monkey-patched on at server.py:229). This is
       what types the ~529 ``current_app.conns.<svc>.<method>()`` call sites.

All of it is local developer-experience change, not intended to be committed.

Usage:
    apply.py [--check | --revert] [--api PATH] [--venv PATH]
"""

from __future__ import annotations

import argparse
import ast
import os
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUB_SRC = HERE / "libgafthrift__init__.pyi"
DOCS_SRC = HERE / "docs" / "inter-service-typing.md"

# master file in this dir -> path relative to the venv's site-packages
VENV_STUBS = {
    HERE / "werkzeug_local.pyi": "werkzeug/local.pyi",
    HERE / "flask_globals.pyi": "flask/globals.pyi",
}

STUB_REL = "libgafthrift/libgafthrift/__init__.pyi"
DOCS_REL = "docs/inter-service-typing.md"

# Matches lua/gaf/lsp.lua basedpyright_python_path().
DEFAULT_VENV = "~/.pyenv/versions/api311"

DUMMY_IMPORT = "from libgafthrift.dummy_wrapper import DummyWrapper"

# path -> (client module, alias). The alias is what the annotation refers to.
#
# Note ai_api: ``conns.ai`` is a chained-assignment alias of the *users*
# wrapper in rest/api/server.py:37, so its client is users.api.Client, not
# ai.api.Client. Verified: ai_proofread / ai_improve_writing / ai_change_tone /
# ai_continue_writing are all declared on gaf_thrift-stubs/users/api.pyi.
ACCESSORS = {
    "rest/api/projects_api.py": ("gaf_thrift.projects.api", "ProjectsThriftClient"),
    "rest/api/users_api.py": ("gaf_thrift.users.api", "UsersThriftClient"),
    "rest/api/drive_api.py": ("gaf_thrift.projects.api", "ProjectsThriftClient"),
    "rest/api/ai_api.py": ("gaf_thrift.users.api", "UsersThriftClient"),
    "rest/api/abtest_api.py": ("gaf_thrift.abtest.api", "AbtestThriftClient"),
    "rest/api/memberships_api.py": ("gaf_thrift.memberships.api", "MembershipsThriftClient"),
}

# Each service handler does ``self.conns = connections`` from an unannotated
# __init__, so ``self.conns`` is Unknown and every ``self.conns.<svc>.<method>()``
# inside the midlayers and daos resolves to Any -- even with the libgafthrift stub
# in place. Every one of these files defines its own ``Connections`` class later
# in the same module, so a forward reference is all that is needed.
#
#
# Only services whose Connections actually holds thrift clients are listed. The
# leaf daos are deliberately excluded: projects_dao/users_dao/messages_dao make
# no outbound RPC at all (their Connections is MySQL handles plus memcache), so
# annotating them buys nothing -- and it costs a lot, because the in-house dict
# cursor from libgafthrift.dao infers imprecisely and every
# ``cursor.fetchone()["col"]`` then reports "No overloads for __getitem__".
# Measured: annotating projects_dao alone added 92 such false errors.
#
# path -> (exact old signature, new signature)
HANDLERS = {}
for _p in (
    "messages_midlayer/messages_mid/api.py",
    "projects_midlayer/projects_mid/api.py",
    "users_midlayer/users_mid/api.py",
):
    HANDLERS[_p] = (
        "def __init__(self, connections):",
        'def __init__(self, connections: "Connections"):',
    )
HANDLERS["pii_store/pii_store/api.py"] = (
    "def __init__(self, connections, rabbit_enabled=True):",
    'def __init__(self, connections: "Connections", rabbit_enabled=True):',
)
HANDLERS["messages_midlayer/messages_mid/smtp_server.py"] = (
    "def __init__(self, connections: Any) -> None:",
    'def __init__(self, connections: "Connections") -> None:',
)

# The mixins carry most of a midlayer's thrift calls but have no __init__ of
# their own -- `conns` is set by the handler class they are mixed into, and
# pyright does not propagate an attribute from a sibling base. A class-level
# annotation fixes it. The import has to be TYPE_CHECKING-guarded because api.py
# imports these modules, so importing Connections back would be circular.
#
# path -> (class name, module holding Connections)
MIXINS = {
    "projects_midlayer/projects_mid/challenges.py": ("ChallengeMixin", "projects_mid.api"),
    "projects_midlayer/projects_mid/contests.py": ("ContestMixin", "projects_mid.api"),
    "projects_midlayer/projects_mid/quotations.py": ("QuotationMixin", "projects_mid.api"),
    "projects_midlayer/projects_mid/service_offerings.py": (
        "ServiceOfferingMixin", "projects_mid.api"),
    "projects_midlayer/projects_mid/timelines.py": ("TimelineMixin", "projects_mid.api"),
    "users_midlayer/users_mid/ai.py": ("AiMixin", "users_mid.api"),
    "users_midlayer/users_mid/canvas.py": ("CanvasMixin", "users_mid.api"),
    "users_midlayer/users_mid/external_credentials.py": (
        "ExternalCredentialsMixin", "users_mid.api"),
    "users_midlayer/users_mid/feed.py": ("FeedMixin", "users_mid.api"),
    "users_midlayer/users_mid/groups.py": ("GroupsMixin", "users_mid.api"),
    "users_midlayer/users_mid/posts.py": ("PostsMixin", "users_mid.api"),
    "users_midlayer/users_mid/superuser_permissions.py": (
        "SuperuserPermissionsMixin", "users_mid.api"),
    "users_midlayer/users_mid/support.py": ("SupportMixin", "users_mid.api"),
    "users_midlayer/users_mid/tasks.py": ("TasksMixin", "users_mid.api"),
    "users_midlayer/users_mid/webhooks.py": ("WebhooksMixin", "users_mid.api"),
    "messages_midlayer/messages_mid/contacts.py": ("ContactsMixin", "messages_mid.api"),
}

MIXIN_MARKER = 'conns: "Connections"'
MIXIN_NOTE = (
    "# Set by the handler class this mixin is mixed into; declared here so\n"
    "# self.conns.<service> resolves to the generated thrift Client.\n"
)

GREEN, YELLOW, RED, DIM, RESET = "\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[0m"
if not sys.stdout.isatty():
    GREEN = YELLOW = RED = DIM = RESET = ""


def rewrite(text: str, module: str, alias: str) -> str:
    """Swap the DummyWrapper import and annotation for the real client."""
    return text.replace(
        DUMMY_IMPORT, f"from {module} import Client as {alias}"
    ).replace("-> DummyWrapper:", f"-> {alias}:")


def state_of(path: Path, alias: str) -> str:
    """One of: applied, pending, foreign, missing."""
    if not path.exists():
        return "missing"
    text = path.read_text()
    if f"-> {alias}:" in text:
        return "applied"
    if "-> DummyWrapper:" in text:
        return "pending"
    return "foreign"


def signature_state(path: Path, old: str, new: str) -> str:
    """One of: applied, pending, foreign, missing."""
    if not path.exists():
        return "missing"
    text = path.read_text()
    if text.count(new) == 1:
        return "applied"
    if text.count(old) == 1:
        return "pending"
    return "foreign"


def mixin_apply(text: str, class_name: str, conns_module: str) -> str | None:
    """Declare `conns` on a mixin. None if already applied."""
    if MIXIN_MARKER in text:
        return None
    lines = text.splitlines(keepends=True)
    tree = ast.parse(text)

    cls = next(
        (n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == class_name), None)
    if cls is None:
        raise ValueError(f"class {class_name} not found at module level")

    first = cls.body[0]
    doc_only = (
        isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant)
        and isinstance(first.value.value, str)
    )
    if doc_only and len(cls.body) > 1:
        anchor = cls.body[1]
        insert_at, indent = anchor.lineno - 1, " " * anchor.col_offset
    elif doc_only:
        insert_at, indent = first.end_lineno, "    "
    else:
        insert_at, indent = first.lineno - 1, " " * first.col_offset

    decl = "".join(indent + ln + "\n" for ln in MIXIN_NOTE.strip().split("\n"))
    decl += f"{indent}{MIXIN_MARKER}\n\n"

    last_import_end = 0
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            last_import_end = max(last_import_end, node.end_lineno)
        elif last_import_end:
            break

    has_tc = any(
        isinstance(n, ast.ImportFrom) and n.module == "typing"
        and any(a.name == "TYPE_CHECKING" for a in n.names)
        for n in ast.walk(tree)
    )
    block = "\n" + ("" if has_tc else "from typing import TYPE_CHECKING\n\n")
    block += f"if TYPE_CHECKING:\n    from {conns_module} import Connections\n"

    lines.insert(insert_at, decl)
    lines.insert(last_import_end, block)
    return "".join(lines)


def mixin_revert(text: str, conns_module: str) -> str | None:
    """Undo mixin_apply. None if nothing to do."""
    if MIXIN_MARKER not in text:
        return None
    out = re.sub(
        r"[ \t]*# Set by the handler class this mixin is mixed into; declared here so\n"
        r"[ \t]*# self\.conns\.<service> resolves to the generated thrift Client\.\n"
        r"[ \t]*conns: \"Connections\"\n\n?",
        "", text)
    out = out.replace(
        f"\nif TYPE_CHECKING:\n    from {conns_module} import Connections\n", "")
    # Drop the typing import too, but only if we were the one who needed it.
    if "TYPE_CHECKING" in out and out.count("TYPE_CHECKING") == 1:
        out = out.replace("\nfrom typing import TYPE_CHECKING\n\n", "\n")
    return out


def site_packages(venv: Path) -> Path | None:
    for sp in sorted(venv.glob("lib/python3.*/site-packages")):
        if sp.is_dir():
            return sp
    return None


def venv_stub_path(venv: Path, rel: str) -> Path | None:
    """<venv>/lib/python3.*/site-packages/<rel>, if the owning package is installed."""
    sp = site_packages(venv)
    if sp is None:
        return None
    dst = sp / rel
    return dst if dst.parent.is_dir() else None


def exclude_stub(api: Path) -> bool:
    """Hide the stub from git without touching the tracked .gitignore."""
    exclude = api / ".git" / "info" / "exclude"
    exclude.parent.mkdir(parents=True, exist_ok=True)
    existing = exclude.read_text() if exclude.exists() else ""
    if STUB_REL in existing.split():
        return False
    with exclude.open("a") as fh:
        if existing and not existing.endswith("\n"):
            fh.write("\n")
        fh.write(f"{STUB_REL}\n")
    return True


def report_stub(label: str, rel: str, dst: Path | None, src: Path) -> bool:
    print(f"{label:<10} {rel}")
    if dst is None:
        print(f"  {RED}target not found{RESET}")
        return False
    if not dst.exists():
        print(f"  {YELLOW}absent{RESET}")
        return False
    if dst.read_text() == src.read_text():
        print(f"  {GREEN}installed, matches master{RESET}")
        return True
    print(f"  {RED}installed but DIFFERS from master{RESET}")
    return False


def do_check(api: Path, venv: Path) -> int:
    ok = report_stub("stub", STUB_REL, api / STUB_REL, STUB_SRC)

    for src, rel in VENV_STUBS.items():
        dst = venv_stub_path(venv, rel)
        print()
        ok = report_stub("venv", str(dst) if dst else f"{venv}/.../{rel}", dst, src) and ok

    print(f"\n{'accessors':<10}")
    counts: dict[str, int] = {}
    for rel, (_module, alias) in ACCESSORS.items():
        st = state_of(api / rel, alias)
        counts[st] = counts.get(st, 0) + 1
        colour = {"applied": GREEN, "pending": YELLOW, "foreign": RED, "missing": RED}[st]
        print(f"  {colour}{st:<8}{RESET} {rel}")

    print(f"\n{'handlers':<10}")
    for rel, (old, new) in HANDLERS.items():
        st = signature_state(api / rel, old, new)
        counts[st] = counts.get(st, 0) + 1
        colour = {"applied": GREEN, "pending": YELLOW, "foreign": RED, "missing": RED}[st]
        print(f"  {colour}{st:<8}{RESET} {rel}")

    print(f"\n{'mixins':<10}")
    for rel, (cls, _mod) in MIXINS.items():
        path = api / rel
        if not path.exists():
            st = "missing"
        elif MIXIN_MARKER in path.read_text():
            st = "applied"
        else:
            st = "pending"
        counts[st] = counts.get(st, 0) + 1
        colour = {"applied": GREEN, "pending": YELLOW, "missing": RED}[st]
        print(f"  {colour}{st:<8}{RESET} {rel}  ({cls})")

    docs = api / DOCS_REL
    print(f"\n{'docs':<10} {DOCS_REL}")
    print(f"  {GREEN}present{RESET}" if docs.exists() else f"  {YELLOW}absent{RESET}")

    return 0 if counts.get("applied") == len(ACCESSORS) + len(HANDLERS) + len(MIXINS) and ok else 1


def do_apply(api: Path, venv: Path) -> int:
    changed = []

    stub_dst = api / STUB_REL
    if not stub_dst.exists() or stub_dst.read_text() != STUB_SRC.read_text():
        stub_dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(STUB_SRC, stub_dst)
        changed.append(f"stub      {STUB_REL}")

    for src, rel in VENV_STUBS.items():
        dst = venv_stub_path(venv, rel)
        if dst is None:
            print(f"{YELLOW}skipped{RESET}   {rel} -- owning package not in {venv}",
                  file=sys.stderr)
        elif not dst.exists() or dst.read_text() != src.read_text():
            shutil.copyfile(src, dst)
            changed.append(f"venv      {dst}")

    if exclude_stub(api):
        changed.append("exclude   .git/info/exclude += stub")

    if DOCS_SRC.exists():
        docs_dst = api / DOCS_REL
        if not docs_dst.exists() or docs_dst.read_text() != DOCS_SRC.read_text():
            docs_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(DOCS_SRC, docs_dst)
            changed.append(f"docs      {DOCS_REL}")

    for rel, (module, alias) in ACCESSORS.items():
        path = api / rel
        st = state_of(path, alias)
        if st == "applied":
            continue
        if st == "missing":
            print(f"{RED}missing{RESET}   {rel}", file=sys.stderr)
            return 1
        if st == "foreign":
            print(
                f"{RED}unrecognised{RESET} {rel} -- neither DummyWrapper nor {alias};"
                " refusing to guess",
                file=sys.stderr,
            )
            return 1
        text = path.read_text()
        if text.count(DUMMY_IMPORT) != 1 or text.count("-> DummyWrapper:") != 1:
            print(
                f"{RED}unexpected shape{RESET} {rel} -- expected exactly one import"
                " and one annotation",
                file=sys.stderr,
            )
            return 1
        path.write_text(rewrite(text, module, alias))
        changed.append(f"accessor  {rel}  -> {alias}")

    for rel, (old, new) in HANDLERS.items():
        path = api / rel
        st = signature_state(path, old, new)
        if st == "applied":
            continue
        if st != "pending":
            print(f"{RED}{st}{RESET} {rel} -- expected exactly one `{old}`", file=sys.stderr)
            return 1
        path.write_text(path.read_text().replace(old, new))
        changed.append(f'handler   {rel}  conns: "Connections"')

    for rel, (cls, mod) in MIXINS.items():
        path = api / rel
        if not path.exists():
            print(f"{RED}missing{RESET}   {rel}", file=sys.stderr)
            return 1
        try:
            new = mixin_apply(path.read_text(), cls, mod)
        except ValueError as exc:
            print(f"{RED}{exc}{RESET} in {rel}", file=sys.stderr)
            return 1
        if new is not None:
            path.write_text(new)
            changed.append(f"mixin     {rel}  {cls}.conns")

    if changed:
        for line in changed:
            print(f"{GREEN}+{RESET} {line}")
    else:
        print(f"{DIM}already applied - nothing to do{RESET}")
    return 0


def do_revert(api: Path, venv: Path) -> int:
    reverted = []
    for rel, (module, alias) in ACCESSORS.items():
        path = api / rel
        if not path.exists():
            continue
        text = path.read_text()
        if f"-> {alias}:" not in text:
            continue
        restored = text.replace(
            f"from {module} import Client as {alias}", DUMMY_IMPORT
        ).replace(f"-> {alias}:", "-> DummyWrapper:")
        path.write_text(restored)
        reverted.append(f"accessor  {rel}")

    for rel, (old, new) in HANDLERS.items():
        path = api / rel
        if path.exists() and new in path.read_text():
            path.write_text(path.read_text().replace(new, old))
            reverted.append(f"handler   {rel}")

    for rel, (_cls, mod) in MIXINS.items():
        path = api / rel
        if not path.exists():
            continue
        new = mixin_revert(path.read_text(), mod)
        if new is not None:
            path.write_text(new)
            reverted.append(f"mixin     {rel}")

    stub = api / STUB_REL
    if stub.exists():
        stub.unlink()
        reverted.append(f"stub      {STUB_REL}")

    for rel in VENV_STUBS.values():
        dst = venv_stub_path(venv, rel)
        if dst is not None and dst.exists():
            dst.unlink()
            reverted.append(f"venv      {dst}")

    for line in reverted:
        print(f"{YELLOW}-{RESET} {line}")
    if not reverted:
        print(f"{DIM}nothing to revert{RESET}")
    print(f"{DIM}note: docs/ and .git/info/exclude left in place{RESET}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--api", default=os.environ.get("GAF_API_ROOT", "~/freelancer-dev/api"))
    ap.add_argument("--venv", default=os.environ.get("GAF_API_VENV", DEFAULT_VENV))
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="report status, change nothing")
    mode.add_argument("--revert", action="store_true", help="undo the patch")
    args = ap.parse_args()

    api = Path(args.api).expanduser().resolve()
    venv = Path(args.venv).expanduser()
    if not (api / ".git").exists():
        print(f"{RED}not a git repo: {api}{RESET}", file=sys.stderr)
        return 1
    for src in (STUB_SRC, *VENV_STUBS):
        if not src.exists():
            print(f"{RED}missing master stub: {src}{RESET}", file=sys.stderr)
            return 1

    if args.check:
        return do_check(api, venv)
    if args.revert:
        return do_revert(api, venv)
    return do_apply(api, venv)


if __name__ == "__main__":
    sys.exit(main())
