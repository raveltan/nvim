# gaf-xdebug
> Xdebug control + profile/trace pipeline for the GAF devbox (port-forward, cachegrind, memory trace).

**Module:** lua/gaf/xdebug.lua
**Setup entry:** `require("gaf.xdebug").setup()` (registers commands + keymaps)
**Tags:** gaf xdebug profile trace cachegrind qcachegrind callgrind

## Scope
Wrapper around the project's `bin/gaf-xdebug` shell script (located by walking up from the current buffer). Exposes three workflows: (1) live step-debugger port-forward, (2) time profile via cachegrind → qcachegrind, (3) memory trace via xdebug trace format aggregated by self/incl/calls. Includes full one-keystroke pipelines (URL → curl with cookie → download → open in GUI / aggregate). All shell-out via async `vim.fn.jobstart` with `DEV_DNS=paths.dev_dns` (always `rtanjaya`).

## Install spec
Required from gaf init (not a plugin):
```lua
if vim.g.gaf then require("gaf.xdebug").setup() end
```

## Public API
### Debugger (live attach)
- `M.start()` — `bin/gaf-xdebug start`. Opens port-forward 9003 to devbox.
- `M.stop()` — stop port-forward.
- `M.validate()` — `bin/gaf-xdebug validate` (IDE key, php.ini, etc).
- `M.logs()` — tail devbox xdebug logs.
- `M.insert_connect()` — insert `xdebug_connect_to_client();` at the line below the cursor (CLI-mode trigger).

### Time profile (cachegrind)
- `M.profile_install()` — `bin/gaf-xdebug install --modes=profile` on devbox.
- `M.profile_list(callback?)` — list remote `cachegrind.out.*` snapshots; calls back with `{ {name, raw}, ... }`.
- `M.profile_download(name?, then_fn?)` — download snapshot (picker if no name) into `vim.g.gaf_xdebug_profile_dir` (default `stdpath('cache')/gaf-xdebug`).
- `M.profile_open(path?)` — render via `callgrind_annotate` in a scratch buffer; picker if no path.
- `M.profile_open_gui(path?)` — open in `qcachegrind`; picker if no path. Falls back to text view if qcachegrind missing.
- `M.profile_latest()` — open newest local snapshot in qcachegrind.
- `M.profile_curl(url?, then_fn?)` — `curl` URL with `cookie: XDEBUG_PROFILE=1`; reads `x-xdebug-profile-filename` response header, yanks basename to `+` register.
- `M.profile_pipeline()` — full chain: URL input → curl → download → `profile_open_gui`.

### Memory trace
- `M.install_all()` — install debug+profile+trace modes on devbox.
- `M.trace_curl(url?, then_fn?)` — `curl` with `cookie: XDEBUG_TRACE=1`; reads `x-xdebug-trace-filename`.
- `M.trace_aggregate(path?, opts?)` — parse xdebug human-readable trace (format=0), aggregate by function. `opts.top_n` (default 50). Renders three tables (by self bytes, by incl bytes, by call count) in a scratch buffer with `filetype=xdebug-trace-summary`. Handles `.xt.gz` via `gunzip -c`.
- `M.trace_latest()` — aggregate newest local trace.
- `M.trace_pipeline()` — full chain: URL → curl → download → aggregate.

### Setup
- `M.setup()` — registers user commands (`:GafXdebug*`) and `<leader>X*` keymaps. Idempotent-ish (commands re-registered on re-call).

## Our config
- DEV_DNS hard-coded to `paths.dev_dns` (= `rtanjaya`) — see user memory: devbox is always rtanjaya.
- Local snapshot dir = `vim.g.gaf_xdebug_profile_dir or stdpath('cache')/gaf-xdebug`.
- Snapshot search dirs: local dir, `/tmp`, project root — covers both downloaded and locally-generated files.
- Curl extra args via `vim.g.gaf_xdebug_curl_args` (e.g. `"-b session=..."`).
- Last URL persisted in `vim.g.gaf_xdebug_curl_last_url` across pipeline invocations.
- Trace aggregation does its own indent-depth tracking to compute SELF vs INCL bytes per function (matched `->` / `<-` pairs).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>Xp` | n | `profile_pipeline()` | Profile URL TIME (input → curl → GUI) |
| `<leader>Xo` | n | `profile_latest()` | Open newest snapshot (GUI) |
| `<leader>XO` | n | `profile_open_gui()` | Pick snapshot → GUI |
| `<leader>Xc` | n | `profile_open()` | Pick snapshot → callgrind text |
| `<leader>Xl` | n | `profile_list()` | List remote snapshots |
| `<leader>Xd` | n | `profile_download → open_gui` | Download remote → GUI |
| `<leader>Xm` | n | `trace_pipeline()` | Profile URL MEMORY (input → curl → aggregate) |
| `<leader>XM` | n | `trace_latest()` | Aggregate newest trace by memory |
| `<leader>Xa` | n | `trace_aggregate()` | Aggregate trace (picker) |
| `<leader>XI` | n | `install_all()` | Install debug+profile+trace on devbox |
| `<leader>Xs` | n | `start()` | Start port-forward |
| `<leader>XS` | n | `stop()` | Stop port-forward |
| `<leader>Xv` | n | `validate()` | Validate IDE setup |

DAP step keymaps (`<leader>dx`, `<leader>dX`, `<leader>dv`) live in [gaf-dap](gaf-dap.md).

## GAF integration
This is a GAF module. `find_root()` locates `bin/gaf-xdebug` by walking up from the current buffer — the script ships with the GAF monorepo. All subprocess calls inject `DEV_DNS=rtanjaya`.

## Links
- Related: [gaf-dap](gaf-dap.md), [dap-nvim-dap](dap-nvim-dap.md)
- External: qcachegrind (`brew install qcachegrind graphviz`), `callgrind_annotate` (valgrind perl script).

## Notes
- `aggregate_trace` is a custom xdebug-format-0 parser — depth from indent length / 2, charges each frame's incl bytes back to its parent's child-charge bucket to compute SELF correctly.
- `.xt.gz` traces are decompressed via `gunzip -c` per-call (not cached).
- Profile/trace pipeline yank the snapshot basename to the `+` register so you can `:GafXdebugProfileDownload <C-r>+` manually if the async chain fails.
- If `qcachegrind` is missing, `profile_open_gui` warns and falls back to `profile_open` (text view).
