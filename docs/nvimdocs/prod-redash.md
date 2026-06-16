# prod-redash
> Run ad-hoc SQL through a Redash server's HTTP API and view results in nvim — no direct DB access required. GAF-gated.

**Repo:** https://github.com/rtanjaya/redash.nvim *(local checkout: `~/redash.nvim`)*
**Local spec:** lua/plugins/redash.lua
**Tags:** database sql redash redshift http gaf csvview

## Scope
Queries run through Redash's own data-source connection over HTTPS, so no VPN,
SSH tunnel, or local `psql`/`mysql` client is needed — only Redash reachability
and an API key. This is **not** a [dadbod](prod-dadbod.md) replacement: dadbod
speaks DB protocols (schema tree, completion); redash.nvim speaks HTTP and is
for warehouses reachable only through Redash.

Self-authored plugin. Four modules: `config` (options + credential resolution),
`api` (submit → poll job → fetch), `ui` (result float / grid / row-detail /
loading spinner / export), `schema` (searchable table sidebar).

## GAF gating
The spec returns `{}` unless `vim.g.gaf` is set (`GAF=1 nvim`), so outside the
GAF profile nothing is registered and `<leader>r` stays free. The matching
which-key group is added in a gated function in `lua/plugins/editor.lua`.

## Our config (lua/plugins/redash.lua)
- `dir = ~/redash.nvim`, lazy-loaded on `cmd` / `<leader>r*` keys / `ft=sql`.
- `data_source_id = 6` — FLN-Redshift (Regular Access); `:RedashSource` to switch.
- `run_key = "<leader>rr"` — buffer-local run key in sql buffers.
- `ui = { style = "csvview" }` — render results via csvview.nvim (dependency).
- `api_key_file = "~/brainskey.txt"` — key file (outside this public repo).
- URL from `$REDASH_URL` (set in `~/.zshrc`) — internal host kept out of git.
- Dependency: `hat0uma/csvview.nvim` with `<Tab>`/`<S-Tab>` column navigation
  and `if`/`af` field text-objects.

## Credentials & URL resolution
- URL: `config.url` → `vim.g.redash_url` → `$REDASH_URL`.
- Key: `config.api_key`/`vim.g.redash_api_key` → `$REDASH_API_KEY` →
  `api_key_cmd`/`vim.g.redash_api_key_cmd` → `api_key_file`/`vim.g.redash_api_key_file`.
- Key never written to disk by the plugin.

## Commands
| Command | Action |
|---|---|
| `:Redash` | open scratch SQL buffer (full tab) |
| `:RedashRun` | run buffer / visual range |
| `:RedashSource` | pick / switch data source |
| `:RedashTables` | open schema sidebar |
| `:RedashCancel` | cancel running query (local poll + curl + `DELETE /api/jobs/<id>`) |

## Keymaps
| Key | Mode | Action |
|---|---|---|
| `<leader>ro` | n | open scratch buffer |
| `<leader>rr` | n, x | run buffer / selection (sql buffers) |
| `<leader>rt` | n | browse schema sidebar |
| `<leader>rs` | n | pick data source |
| `<leader>rk` | n | cancel running query |

**Result window:** `<CR>` row detail · `e` export (CSV/TSV/JSON/Markdown file or clipboard) · `q`/`<Esc>` close · `<Tab>`/`<S-Tab>` next/prev column · `if`/`af` field text-objects (csvview).

**Schema sidebar:** `<CR>` expand table / insert column · `i` insert name · `p` preview (`SELECT * ... LIMIT 100`) · `/` filter · `f` fuzzy pick · `r` refresh · `q` close.

## Options (defaults)
- `poll_ms = 1000`, `timeout_ms = 120000`, `max_rows = 2000`.
- `ui.style` *("float"|"split"|"csvview")* — result renderer.
- `ui.border`, `ui.width`, `ui.height`, `ui.max_col_width`, `ui.sidebar_width`.
- `ui.scratch_completion = false` — autocomplete off in the scratch buffer
  (ft=sql but no dadbod connection → blink's Dadbod source emits junk).
- `ui.scratch_open = "tab"` — `tab` (full) | `split` | `vsplit`.
- `run_key = "<leader>Dx"` (we override to `<leader>rr`).

## Links
- Plugin README / `:help redash`
- Related: [prod-dadbod](prod-dadbod.md) (protocol-level DB client); result rendering via [csvview.nvim](https://github.com/hat0uma/csvview.nvim)
- GAF profile: [gaf-overview](gaf-overview.md)

## Notes
- `curl` must be on `$PATH` (the only external dependency).
- Loading indicator: animated bottom-right float with elapsed time, from submit
  until results render — independent of poll cadence / notify backend.
- Exports use raw stored values (full result set, not the row-capped render)
  with RFC-style quoting; nulls and embedded newlines preserved.
- Multi-line cell values are collapsed to a `↵` marker in the grid so each row
  stays one buffer line.
