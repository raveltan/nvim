# prod-kulala
> REST/HTTP client inside nvim: write `.http`/`.rest` files and fire requests, view formatted responses, switch environments.

**Repo:** https://github.com/mistweaverco/kulala.nvim

**Local spec:** lua/plugins/productivity.lua (kulala block, after dadbod-grip)
**Tags:** http rest api client curl graphql request environment

## Scope
A REST Client (Postman/`rest-client`-style) that lives in the buffer. You author
requests in plain `.http`/`.rest` files, then send them and inspect the response
(body / headers / verbose / stats) in a split. Supports variables, environment
files, scripting, GraphQL, gRPC, auth flows, and cURL import/export.

- **Request runner:** `kulala-core` — a standalone binary that auto-downloads
  from GitHub releases on first run (matched to the installed plugin tag). No
  manual install step.
- **Transport:** `curl` (must be on `$PATH`).
- **Response formatting:** `jq` for JSON, `prettier` for JS/GraphQL/HTML,
  `xmllint` for XML, `stylua` for Lua — each used only if found on `$PATH`,
  otherwise the raw response is shown.

## Install spec
```lua
{
  "mistweaverco/kulala.nvim",
  version = "*",
  ft = { "http", "rest" },
  opts = { global_keymaps = false, ui = { ... } },
  keys = { ... }, -- explicit <leader>R* maps, see below
}
```

Loads on `http`/`rest` filetypes, plus the global `keys` (open / send /
scratchpad / replay) which work from any buffer and lazy-load the plugin.

## Our config
- `global_keymaps = false` — kulala's own default bindings are **off**; this
  config defines every `<leader>R*` map explicitly (see Keymaps) so which-key
  descriptions are ours and the prefix is owned cleanly.
- `default_env = "default"` — environment selected at startup.
- `vscode_rest_client_environmentvars = true` — also reads
  `.vscode/settings.json` / `*.code-workspace` `rest-client.environmentVariables`
  (merged under, and overridden by, `http-client.env.json` if both exist).
- `ui.display_mode = "split"`, `ui.split_direction = "vertical"` — response
  opens in a vertical split, not a float.
- `ui.default_view = "body"` — body shown first; `<leader>Rt` toggles to headers.
- `ui.winbar = true` — pane switcher (body / headers / verbose / stats) on the
  result window.
- `ui.show_request_summary = true` — status/time/size summary line.

## Common customizations
- `default_view` *("body"|"headers"|"headers_body"|"verbose"|"script_output"|"stats"|fn, "body")* — initial result pane; a function gets the `Response` object.
- `ui.display_mode` *("split"|"float", "split")* and `ui.split_direction` *("vertical"|"horizontal", "vertical")*.
- `ui.winbar` *(bool, true)* and `ui.default_winbar_panes` *(table)* — which panes appear in the winbar switcher.
- `default_env` *(string, "default")* — picked from `http-client.env.json` / `.env` env blocks.
- `contenttypes` *(table)* — per-MIME `ft` + `formatter` + `pathresolver`; override to add/disable response formatting (e.g. drop `jq`).
- `global_keymaps` *(bool|table, false)* — `true` registers kulala's defaults under `global_keymaps_prefix`; a table sets custom maps. We keep it `false` and map by hand.
- `kulala_core.path` *(string, nil)* — pin a local `kulala-core` binary instead of auto-download; `kulala_core.timeout` *(ms, 60000)* subprocess timeout.

See configuration-options doc: https://neovim.getkulala.net/docs/getting-started/configuration-options

## Writing a request
A `.http` file:
```http
@base = https://api.example.com

### Get a user
GET {{base}}/users/1
Accept: application/json

### Create a user
# @name createUser
POST {{base}}/users
Content-Type: application/json

{ "name": "Ada" }
```
`###` separates requests; `@var = value` defines variables; `{{var}}` interpolates.
Environment-specific values live in `http-client.env.json` next to the file.
Put the cursor in a request and `<leader>Rs` to send it.

## Keymaps — `<leader>R*`
Global (any buffer):

| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>Ro` | n | `kulala.open()` | open UI |
| `<leader>Rb` | n | `kulala.scratchpad()` | scratchpad (ad-hoc request buffer) |
| `<leader>Rs` | n, v | `kulala.run()` | send request under cursor / selection |
| `<leader>Ra` | n, v | `kulala.run_all()` | send all requests in file |
| `<leader>Rr` | n | `kulala.replay()` | replay last request |

`http`/`rest` buffers only:

| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>Rt` | n | `kulala.toggle_view()` | toggle headers/body |
| `<leader>Ri` | n | `kulala.inspect()` | inspect parsed request |
| `<leader>RS` | n | `kulala.show_stats()` | response timing stats |
| `<leader>Rf` | n | `kulala.search()` | find request (picker) |
| `<leader>Rn` / `<leader>Rp` | n | `kulala.jump_next()` / `jump_prev()` | next / prev request |
| `<leader>Re` | n | `kulala.set_selected_env()` | select environment |
| `<leader>Rc` | n | `kulala.copy()` | copy as cURL |
| `<leader>RC` | n | `kulala.from_curl()` | paste from cURL |
| `<leader>Rj` | n | `kulala.open_cookies_jar()` | open cookies jar |
| `<leader>Rg` | n | `kulala.download_graphql_schema()` | download GraphQL schema |
| `<leader>Rq` | n | `kulala.close()` | close result window |
| `<leader>Rx` / `<leader>RX` | n | `scripts_clear_global()` / `clear_cached_files()` | clear globals / cached files |

which-key group label: `<leader>R` → `rest (kulala)` (registered in lua/plugins/editor.lua).

## Links
- Repo: https://github.com/mistweaverco/kulala.nvim
- Docs site: https://neovim.getkulala.net
- Default keymaps: https://neovim.getkulala.net/docs/getting-started/default-keymaps
- Related: [prod-dadbod](prod-dadbod.md), [prod-redash](prod-redash.md) (other in-editor query/HTTP clients)

## Notes
- `curl` is required. `jq` is strongly recommended for readable JSON — without it responses appear unformatted.
- `kulala-core` downloads on first request; the very first run may pause while it fetches the binary. Pin `kulala_core.path` for offline/locked-down setups.
- Default kulala bindings are intentionally disabled (`global_keymaps = false`); if you ever want them, set `global_keymaps = true` and remove the explicit `keys` to avoid double-mapping.
- Sibling in-editor clients: [prod-dadbod](prod-dadbod.md) (SQL), [prod-redash](prod-redash.md) (Redash HTTP SQL, GAF-only).
