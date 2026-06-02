# editor-refjump
> Cycle through LSP references inline with `]r` / `[r` — no picker, no quickfix.

**Repo:** https://github.com/mawkler/refjump.nvim
**Local spec:** lua/plugins/editor.lua:583-589
**Tags:** lsp, references, navigation, editor

## Scope

`refjump.nvim` answers "where else is this symbol used?" without disrupting flow. `]r`/`[r` step through `textDocument/references` results one match at a time and flash a highlight on the landing site. Compared to `vim.lsp.buf.references` (which dumps a quickfix list) or a Telescope/Snacks picker, refjump is a pure motion.

## Install spec

```lua
{
  "mawkler/refjump.nvim",
  keys = { "]r", "[r" },
  opts = {
    keymaps = { enable = true },
    highlights = { enable = true },
  },
}
```

Lazy-loaded on the two motions. `keymaps.enable = true` lets the plugin install `]r`/`[r` itself (we don't bind them in `keys =` rhs).

## Common customizations

- `keymaps.enable` *(bool, true)* — install default `]r`/`[r` (and `]R`/`[R` for "force pick") mappings.
- `keymaps.next` *(string, "]r")* — next reference.
- `keymaps.prev` *(string, "[r")* — previous reference.
- `keymaps.next_repeat` / `prev_repeat` — single-char repeats for `;`/`,` style after a jump.
- `highlights.enable` *(bool, true)* — flash the landed reference.
- `highlights.group` *(string, "IncSearch")* — hlgroup for the flash.
- `highlights.timeout` *(integer, 250)* — ms before the highlight fades.
- `verbose` *(bool, true)* — print "no references found" / wrap notifications.
- `cache` *(bool, true)* — reuse last LSP result while cursor stays on the same symbol (huge speedup when stepping through many refs).
- `integrations.demicolon.enabled` *(bool, false)* — interop with `demicolon.nvim` so `;`/`,` repeat the last refjump motion.

WebFetch https://raw.githubusercontent.com/mawkler/refjump.nvim/HEAD/README.md for the exhaustive opts.

## Our config

```lua
keymaps = { enable = true },
highlights = { enable = true },
```

Both default to true upstream, so this is essentially "enable plugin, accept defaults". The explicit form documents intent and protects against an upstream default flip.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `]r` | n | next LSP reference | Cycle forward through references of symbol under cursor |
| `[r` | n | prev LSP reference | Cycle backward |

Plugin also registers visual/operator-pending variants when `keymaps.enable` is true.

## Links

- Plugin repo: https://github.com/mawkler/refjump.nvim

## Notes

- Requires an attached LSP server that implements `textDocument/references`. Falls back to a "no references" notification otherwise.
- The cache means a stale rename can leave you jumping to a freed location; press `]r` after touching the symbol to refresh.
