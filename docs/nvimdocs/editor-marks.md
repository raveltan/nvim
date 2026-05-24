# editor-marks
> Sign-column indicators and richer keymaps for vim marks and bookmarks.

**Repo:** https://github.com/chentoast/marks.nvim
**Local spec:** lua/plugins/editor.lua:272-277
**Tags:** marks, bookmarks, signs, navigation, editor

## Scope

`marks.nvim` renders builtin marks (`a`–`z`, `A`–`Z`, `0`–`9`, `^`, `.`, etc.) in the sign column and adds a layer of mnemonic keymaps for setting, deleting, and jumping. It also introduces "bookmark groups" (`mp`/`md`/`ml`/...) — labelled marks with their own signs that survive across files.

## Install spec

```lua
{
  "chentoast/marks.nvim",
  event = "BufReadPost",
  opts = {
    default_mappings = true,
  },
}
```

Loads on first buffer read so the sign column is populated immediately.

## Common customizations

- `default_mappings` *(bool, true)* — install the full `m*` keymap set. Set `false` to wire your own via `require("marks").mappings`.
- `builtin_marks` *(string[], {})* — extra builtin marks to track besides letter marks (e.g. `{ ".", "<", ">", "^" }`).
- `cyclic` *(bool, true)* — `]`'`/`[`'` wrap around the buffer.
- `force_write_shada` *(bool, false)* — write shada on every mark op (slower but survives crashes).
- `refresh_interval` *(integer, 250)* — ms between sign refresh polls.
- `sign_priority` *(integer|table, 10)* — sign priority; can be per-class (`{ lower=10, upper=15, builtin=8, bookmark=20 }`).
- `excluded_filetypes` *(string[], {})* — filetypes where marks.nvim disables itself.
- `excluded_buftypes` *(string[], {})* — same but per `buftype`.
- `bookmark_0` … `bookmark_9` *(table)* — per-group sign, virt_text, virt_text_pos, annotate flag.
- `mappings` *(table)* — override any individual action key (e.g. `{ next = "m]", preview = "m:" }`).

WebFetch https://raw.githubusercontent.com/chentoast/marks.nvim/HEAD/README.md if option names drift.

## Our config

Just `default_mappings = true` — everything else stays upstream default. Builtin marks are not added; bookmark groups use default signs.

## Keymaps

Default mappings provided by the plugin (all in normal mode):

| Key | Action | Desc |
|-----|--------|------|
| `m{a-zA-Z}` | set mark | Standard vim — but now visible in sign column |
| `m,` | set next unused lowercase mark | Auto-pick free letter |
| `m;` | toggle next mark on current line | Quick line bookmark |
| `dm{a-zA-Z}` | delete mark | |
| `dm-` | delete all marks on line | |
| `dm<space>` | delete all marks in buffer | |
| `m]` | next mark | |
| `m[` | prev mark | |
| `m:` | preview mark (popup) | |
| `mp` | toggle bookmark group 0 | |
| `mP` | delete all bookmark-group-0 | |
| `m]` `m[` over bookmarks | cycle within active group | |

## Links

- Plugin repo: https://github.com/chentoast/marks.nvim
- Vim mark primer: `:help mark-motions`

## Notes

- Bookmark groups `mp`/`md`/...`ml` are separate from letter marks; their signs default to digits.
- With `default_mappings = true`, the `m` prefix is largely owned by this plugin — anything you bind under `m*` should be checked against this set.
- Sign column collisions: gitsigns and diagnostics share the column. Adjust `sign_priority` if you want marks above/below them.
