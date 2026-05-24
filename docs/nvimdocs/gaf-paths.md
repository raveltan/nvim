# gaf-paths
> Single source of truth for Freelancer-specific filesystem and host constants.

**Local file:** lua/gaf/paths.lua
**Tags:** gaf freelancer paths devbox fl-gaf constants

## Scope

Centralises every hard-coded path or hostname referenced by the GAF profile. Any new GAF module that needs the fl-gaf checkout, the devbox SSH name, or the in-container mount point should require this module instead of inlining strings. This keeps refactors safe and makes the devbox name swappable in exactly one place (if it ever changes — currently it doesn't).

## How it loads

Plain require. Has no side effects, no `setup()`. Loaded on-demand by other `lua/gaf/*` modules:

```lua
local paths = require("gaf.paths")
```

Not gated on `vim.g.gaf` itself — gating happens at the call site. If you require this without the GAF profile active, you just get strings (no harm done).

## Public API

```lua
local M = {}
M.dev_root    = vim.fn.expand("~/freelancer-dev")
M.fl_gaf      = vim.fn.expand("~/freelancer-dev/fl-gaf")
M.remote_root = "/mnt/gaf"
M.dev_dns     = "rtanjaya"
return M
```

- `M.dev_root` — local parent dir containing every Freelancer checkout (also added to Snacks project picker `dev` paths).
- `M.fl_gaf` — the PHP monorepo root. Used by `bin/run-tests`, php-cs-fixer config lookup, phpcs ruleset lookup, neotest cwd resolution.
- `M.remote_root` — bind-mount inside the devbox container where the host's checkout appears. Used by DAP's `pathMappings` so xdebug step-debugging maps remote paths back to local files.
- `M.dev_dns` — SSH alias for the user's devbox. **Always `rtanjaya`** — per user preference, do not parameterize this. Used to construct `ssh rtanjaya ...` port-forward commands in xdebug helpers.

## Keymaps / Commands

None — this is a constants module.

## Workflow examples

```lua
-- Resolve a path inside the fl-gaf checkout
local paths = require("gaf.paths")
local phpcs_rules = paths.fl_gaf .. "/phpcs_gaf.xml"

-- Open a port-forward to the devbox
local cmd = { "ssh", "-N", "-R", "9003:localhost:9003", paths.dev_dns }
```

## Links

- [gaf-overview](gaf-overview.md) — profile bootstrap
- [gaf-dap](gaf-dap.md) — uses `remote_root` for `pathMappings`
- [gaf-test-infra](gaf-test-infra.md) — uses `fl_gaf` as cwd

## Notes

- Hostname is intentionally **hard-coded**, not derived from `$USER` or `~/.ssh/config`. See user memory `gaf_dev_dns.md`.
- `vim.fn.expand("~")` happens at require time — runs once per nvim session.
- Worktrees live as siblings of `fl-gaf` (e.g. `~/freelancer-dev/fl-gaf-worktree/<branch>/`). The neotest run-tests script handles both because each worktree carries its own `bin/run-tests`.
