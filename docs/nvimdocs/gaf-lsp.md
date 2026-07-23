# gaf-lsp

> LSP server tweaks for Freelancer repos — basedpyright monorepo wiring for `~/freelancer-dev/api`, tailwindcss disabled.

**Local file:** lua/gaf/lsp.lua
**Tags:** gaf freelancer lsp basedpyright python api thrift tailwindcss mason intelephense

## Scope

Holds the GAF-specific LSP overrides applied from `lua/plugins/lsp.lua`. Three surfaces:

1. Filters `tailwindcss` out of `mason-lspconfig` ensure_installed because the fl-gaf webapp doesn't use Tailwind.
2. Provides the **absolute** `extraPaths` list for `basedpyright` so Python type-resolution works across the `~/freelancer-dev/api` monorepo.
3. Provides the interpreter path (`api311` pyenv venv) so third-party imports (Flask, boto3, `gaf_thrift`, …) resolve.

PHP intelephense settings (memory, stubs, large-file include limits) live in `lua/plugins/lsp.lua` itself, not here — this module is just the GAF deltas.

## Why the api repo needs all this

`~/freelancer-dev/api` is a multi-package Python 3.11 monorepo. Three quirks break a default pyright setup:

- **Inner packages with different names.** Each top-level service dir is its own setuptools project and the importable package sits one level inside, often renamed: `rest/` → `import api`, `users_midlayer/` → `users_mid`, `projects_midlayer/` → `projects_mid`, `messages_midlayer/` → `messages_mid`. The *outer* dirs must be on the search path.
- **Per-service `setup.py` hijacks root detection.** basedpyright's default root markers are a flat list where `setup.py` outranks `.git`, so opening `users_midlayer/...` would root the server at `users_midlayer/` — one server per service, cross-service imports dead. Fixed with priority-ordered root markers (`{ { ".git" }, { ... } }`, nvim 0.11.3+) gated under GAF in `plugins/lsp.lua`.
- **Deps live only in Docker.** The repo has no committed venv; runtime deps come from the private Nexus mirror inside `api-py311-base` images. A local pyenv venv stands in for the LSP (see Setup).

Thrift types come from `gaf_thrift-stubs/` at the repo root — a **gitignored, generated** PEP-561 stub package for the `gaf_thrift` pip dep. Keeping the repo root itself in `extraPaths` lets pyright auto-discover it. If it's missing (fresh clone), regenerate via the thrift repo (`run.sh build_thrift_definitions`).

## Setup (one-time, per machine)

Everything is nvim-config-only — **no files are added to the api repo** (no pyrightconfig.json, no ruff.toml).

```sh
# 1. Interpreter venv, lives outside the repo under ~/.pyenv
pyenv virtualenv 3.11.14 api311

# 2. Editable-install the 10 services WITHOUT deps (fast; full dependency
#    resolution stalls on ancient pins like Flask 0.11 / uWSGI sdists).
#    Editable installs only write gitignored *.egg-info/ dirs.
cd ~/freelancer-dev/api
for svc in restutils libgafthrift users_dao messages_dao projects_dao \
           pii_store users_midlayer messages_midlayer projects_midlayer rest; do
  ~/.pyenv/versions/api311/bin/pip install -q --no-deps -e ./$svc
done

# 3. Third-party deps from the Nexus mirror, one at a time so a single
#    broken pin doesn't block the rest (uWSGI skipped — native build,
#    useless for completion). Union of deps comes from the *.egg-info
#    requires.txt files step 2 generated.
python3 - <<'EOF' > /tmp/api-deps.txt
import glob, re
from packaging.markers import Marker
reqs = set()
for path in glob.glob("/Users/rtanjaya/freelancer-dev/api/*/*.egg-info/requires.txt"):
    marker = None
    for line in open(path):
        line = line.strip()
        if not line: continue
        m = re.match(r"^\[(.*)\]$", line)
        if m:
            sec = m.group(1)
            marker = sec[1:] if sec.startswith(":") else "SKIP"
            continue
        if marker == "SKIP": continue
        if marker and not Marker(marker).evaluate({"python_version": "3.11"}): continue
        reqs.add(line)
for r in sorted(reqs):
    if not re.match(r"^uwsgi", r, re.I): print(r)
EOF
while IFS= read -r req; do
  ~/.pyenv/versions/api311/bin/pip install -q --prefer-binary \
    -i https://nexus.tools.flnltd.com/repository/pypi/simple "$req" \
    || echo "FAIL: $req"
done < /tmp/api-deps.txt

# 4. (Re)generate the thrift stubs whenever they're missing or stale —
#    stale stubs surface as reportAttributeAccessIssue on fields the code
#    clearly uses. api/run.sh does NOT expose this; call the thrift repo:
cd ~/freelancer-dev/thrift/thrift-service
EXPORT=~/freelancer-dev/api/gaf_thrift-stubs ./run.sh generate-stubs
```

The venv is optional: `plugins/lsp.lua` only sets `python.pythonPath` when the binary exists (`vim.fn.executable`), so a machine without it degrades gracefully to intra-repo + thrift-stub completion; only third-party imports stay unresolved.

Formatting needs no setup — the repo's own gate is `black==23.12.0` with defaults (line length 88), and `ruff format` (already the conform formatter for python) is black-compatible at 88 out of the box. flake8's 119 in `setup.cfg` is only a max.

## How it loads

Required directly from `lua/plugins/lsp.lua` inside `if vim.g.gaf then ... end` blocks. No `setup()` — pure functions returning data.

```lua
-- In plugins/lsp.lua's mason-lspconfig config:
if vim.g.gaf then
  ensure_installed = require("gaf.lsp").filter_mason_servers(ensure_installed)
end

-- In the basedpyright vim.lsp.config block (see plugins/lsp.lua for the
-- full block: also sets typeCheckingMode = "standard" and root_markers):
if vim.g.gaf then
  analysis.extraPaths = require("gaf.lsp").basedpyright_extra_paths()
  local py = require("gaf.lsp").basedpyright_python_path()
  if vim.fn.executable(py) == 1 then
    settings.python = { pythonPath = py }
  end
end
```

## Public API

- `M.filter_mason_servers(servers)` — removes `"tailwindcss"` from the input table. Returns a new filtered table (uses `vim.tbl_filter`).
- `M.basedpyright_extra_paths()` — returns **absolute** paths: the api repo root (for `gaf_thrift-stubs` discovery) plus the 10 outer service dirs (`rest`, `restutils`, `libgafthrift`, `pii_store`, `users_midlayer`, `users_dao`, `messages_midlayer`, `messages_dao`, `projects_midlayer`, `projects_dao`).
- `M.basedpyright_python_path()` — returns `~/.pyenv/versions/api311/bin/python` (expanded).

## Keymaps / Commands

None — pure data helpers.

## Workflow examples

```lua
-- Disabling another server under GAF profile only:
function M.filter_mason_servers(servers)
  local drop = { tailwindcss = true, eslint = true }   -- example: also drop eslint
  return vim.tbl_filter(function(s) return not drop[s] end, servers)
end

-- Adding a new service dir after the api repo grows one:
-- append it to the `services` list in M.basedpyright_extra_paths().
```

## Links

- [gaf-overview](gaf-overview.md) — profile bootstrap
- [lsp-mason-lspconfig](lsp-mason-lspconfig.md) — ensure_installed wiring
- [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md) — basedpyright + intelephense config
- [ftplugin-php](ftplugin-php.md) — PHP buffer tricks (`$$` → `$this->`, native rename)

## Notes

- PHP buffers use **native** `vim.lsp.buf.rename`, not `inc-rename`, due to intelephense `$` sigil handling — see [ftplugin-php](ftplugin-php.md).
- Tailwind is filtered (not just disabled) so `mason-lspconfig` won't even download it on a fresh fl-gaf-only machine. Other configs (non-GAF) keep tailwindcss.
- `extraPaths` used to be relative (`{ "libgafthrift", "restutils" }`) — that silently broke whenever the server rooted at a service dir instead of the repo root. Absolute paths + `.git`-first root markers fixed both at once.
- `typeCheckingMode = "standard"` under GAF because basedpyright's default (`recommended`) floods the legacy api code; mypy-in-docker (`lib/bin/mypy`) is the repo's real type gate.
- **Stub-convention false positives are silenced** via GAF-gated `diagnosticSeverityOverrides` in `plugins/lsp.lua`. The generated stubs use the legacy mypy convention `INVALID_REQUEST: int = ...` inside `class Foo(Enum)` — the current typing spec (and so pyright) reads annotated enum attrs as plain `int` non-members, so every `FooCodes.X` argument false-errored (`reportArgumentType`, 167 errors in one measured file). Thrift `Iface` multiple inheritance likewise trips `reportIncompatibleMethodOverride` (84), and stub-only packages warn `reportMissingModuleSource` (62). All three → `"none"`. The `reportOptional*` family is downgraded to `"warning"` — genuinely useful for new code, endemic in legacy code. Measured effect on `projects_mid/api.py`: 337 errors → ~50.
- `reportAttributeAccessIssue` is downgraded to **warning**, not off — it catches real typos, but pyright's return-type inference through unannotated legacy helpers (e.g. `libgafthrift`'s `patch_filter_with_searchable_pool_ids`, whose `isinstance` branches make pyright infer a union including users' `DirectoryFilter`) false-flags attribute access on the wrong union member. mypy treats unannotated returns as `Any`, so the docker gate never sees these. If it fires on thrift struct fields the code clearly uses, also consider stale stubs → regenerate (Setup step 4).
- The api repo dirs are hard-coded to `~/freelancer-dev/api`, same convention as `gaf/paths.lua` hard-coding fl-gaf.
- Add fl-gaf-only intelephense stubs / include paths the same way: extend this module + gate the application in `plugins/lsp.lua`.
