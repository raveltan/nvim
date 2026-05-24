# editor-ultimate-autopair
> Autopairs with smart multiline, JSX, and quote handling. `<CR>` handler disabled to keep vim-endwise working.

**Repo:** https://github.com/altermo/ultimate-autopair.nvim
**Local spec:** lua/plugins/editor.lua:37-44
**Tags:** autopair, insert, brackets

## Scope
Auto-inserts the closing half of brackets/quotes/tags in insert and cmdline mode, with context-aware skipping (don't double-pair inside strings, JSX-aware, etc.). Pinned to `branch = "v0.6"` for API stability.

## Install spec
```lua
{
  "altermo/ultimate-autopair.nvim",
  event = { "InsertEnter", "CmdlineEnter" },
  branch = "v0.6",
  opts = {
    cr = { enable = false },
  },
}
```

## Common customizations
- `bs.enable` *(bool, true)* — when deleting an open pair, also delete the close.
- `cr.enable` *(bool, true)* — on `<CR>` inside `{|}` etc., split into `{\n|\n}`.
- `space.enable` *(bool, true)* — `{ | }` style padding with one space key.
- `space2.enable` *(bool, false)* — extended space behaviour.
- `fastwarp.enable` *(bool, true)* — `<M-e>` to warp closing pair around next word.
- `tabout.enable` *(bool, false)* — `<Tab>` jumps over closing pair.
- `extensions.cond` — predicate-based gating per-pair.
- `extensions.filetype.tree` — per-filetype rule overrides.
- `extensions.escape.filetype` — disable escape-pair behaviour per filetype.
- `pair_map` *(table)* — declare custom pairs, e.g. `{ "<", ">" }` for JSX/HTML.

## Our config
- `cr = { enable = false }` — disabled because:

  > its `<CR>` handler remaps `imap <CR>` with `noremap=true` and displaces vim-endwise's `<Plug>DiscretionaryEnd` map. Disabling restores the endwise chain so blink.cmp's "fallback" finds endwise and inserts `end` for `def`/`do`/`if`/`class`/`module` on Enter in Ruby/Lua/Vim buffers.
  > Trade-off: typing `<CR>` inside `{|}` no longer expands to `{\n|\n}` — use `o` or a snippet for that case.

  (Comment from lua/plugins/editor.lua:30-36.)

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<bracket>` | i | auto-pair | Insert open + close, place cursor between |
| `<bs>` | i | smart delete | Delete pair when between open/close |
| `<M-e>` | i | fastwarp | Warp closing pair around next word (default) |

No `<leader>` mappings.

## Links
- README: https://github.com/altermo/ultimate-autopair.nvim/blob/v0.6/README.md
- Docs: https://github.com/altermo/ultimate-autopair.nvim/blob/v0.6/doc/ultimate-autopair.txt

## Notes
- The `cr.enable = false` trade-off is intentional — endwise/blink.cmp fallback chain matters more than the `{|}` → `{\n|\n}` expansion in our workflow.
- Pinned to `v0.6` branch; upstream main may break the option layout.
- Loads on `InsertEnter` and `CmdlineEnter` so cmdline `:` parens also auto-pair.
