# prod-dadbod
> Database client inside nvim: connect, browse schemas, run SQL with column completion.

**Repo:**
- engine: https://github.com/tpope/vim-dadbod
- ui: https://github.com/kristijanhusak/vim-dadbod-ui
- completion: https://github.com/kristijanhusak/vim-dadbod-completion

**Local spec:** lua/plugins/productivity.lua:100-138
**Tags:** database sql postgres mysql sqlite completion

## Scope
Three plugins composed:
- **vim-dadbod** — the engine. Defines `:DB` to execute queries against a URL/connection name.
- **vim-dadbod-ui** — a NerdTree-style sidebar listing connections, schemas, tables, saved queries, and a scratchpad. Provides `:DBUI*` commands.
- **vim-dadbod-completion** — `omnifunc` source for SQL buffers; produces table/column/keyword completions. Picked up automatically by blink.cmp via omni source.

## Install spec
```lua
{
  "tpope/vim-dadbod",
  cmd = { "DB" },
  dependencies = {
    {
      "kristijanhusak/vim-dadbod-ui",
      cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
      init = function() vim.g.db_ui_* = ... end,
    },
    "kristijanhusak/vim-dadbod-completion",
  },
  keys = { ... },
  config = function() ... end,
}
```

## Common customizations
### vim-dadbod (engine)
- `vim.g.dbs` *(table, nil)* — named connections, e.g. `{ rails_dev = "postgresql://user@localhost/myapp_dev" }`. Per-project recommended.
- `vim.g.db` *(string, nil)* — fallback connection URL.
- Per-buffer: `:let b:db = "postgresql://..."` or `:DB g:dbs.rails_dev SELECT ...`.

### vim-dadbod-ui
- `g:db_ui_use_nerd_fonts` *(0|1, 0)* — icons.
- `g:db_ui_show_database_icon` *(0|1, 0)* — db engine icon next to connections.
- `g:db_ui_force_echo_notifications` *(0|1, 0)* — use `:echo` even when notify plugin loaded.
- `g:db_ui_use_nvim_notify` *(0|1, 0)* — route notifications through `vim.notify`.
- `g:db_ui_win_position` *("left"|"right", "left")* — sidebar side.
- `g:db_ui_winwidth` *(number, 40)* — sidebar columns.
- `g:db_ui_save_location` *(string, "~/.local/share/db_ui")* — where saved queries live.
- `g:db_ui_auto_execute_table_helpers` *(0|1, 0)* — run helper queries when opening a table.
- `g:db_ui_table_helpers` *(table)* — custom per-engine table actions.
- `g:db_ui_execute_on_save` *(0|1, 1)* — run query on `:w`.

### vim-dadbod-completion
- `vim.bo.omnifunc = "vim_dadbod_completion#omni"` (set per-buffer; we wire this in a FileType autocmd).
- `g:vim_dadbod_completion_mark` *(string, "[DB]")* — label in popup.

See:
- vim-dadbod README: https://github.com/tpope/vim-dadbod
- dadbod-ui doc: https://github.com/kristijanhusak/vim-dadbod-ui/blob/master/doc/dadbod-ui.txt

## Our config
- `g:db_ui_use_nerd_fonts = 1`
- `g:db_ui_show_database_icon = 1`
- `g:db_ui_force_echo_notifications = 1`
- `g:db_ui_win_position = "left"`, `g:db_ui_winwidth = 40`
- `g:db_ui_save_location = stdpath('data') .. '/db_ui'` (under `~/.local/share/nvim/`)
- `g:db_ui_use_nvim_notify = 1`
- `g:db_ui_auto_execute_table_helpers = 1` — helper queries fire on table open.
- FileType autocmd for `sql,mysql,plsql` sets `vim.bo.omnifunc = "vim_dadbod_completion#omni"` so blink.cmp's omni source picks up DB completions.

Connections come from either `~/.local/share/db_ui/connections.json` (added via `:DBUIAddConnection`) or a project-local `vim.g.dbs` table.

## Keymaps
| Key | Action | Desc |
|---|---|---|
| `<leader>Du` | `:DBUIToggle` | DB: toggle UI |
| `<leader>Df` | `:DBUIFindBuffer` | DB: find buffer |
| `<leader>Da` | `:DBUIAddConnection` | DB: add connection |
| `<leader>Dr` | `:DBUIRenameBuffer` | DB: rename buffer |
| `<leader>Dq` | `:DBUILastQueryInfo` | DB: last query info |

In a SQL buffer: `<leader>S` (or whatever dadbod-ui maps) runs the buffer/selection. `:w` re-executes by default.

## Links
- vim-dadbod: https://github.com/tpope/vim-dadbod
- vim-dadbod-ui: https://github.com/kristijanhusak/vim-dadbod-ui
- vim-dadbod-completion: https://github.com/kristijanhusak/vim-dadbod-completion
- Related: [cmp-blink](cmp-blink.md)

## Notes
- Postgres/MySQL CLI binaries (`psql`, `mysql`) must be on `$PATH` — dadbod shells out.
- SQLite/DuckDB also supported; URL schemes are `sqlite:`, `duckdb:`, `mongodb:`, `bigquery:`, etc.
- The completion plugin listens for connection context; if no connection is bound to the buffer (e.g. ad-hoc `.sql` file), only keyword completions appear.
- `db_ui_execute_on_save=1` is the default — saving a query buffer runs it. Disable per-buffer if that surprises you on a slow query.
