# editor-quicker
> Editable, prettified quickfix window with context-expansion controls.

**Repo:** https://github.com/stevearc/quicker.nvim
**Local spec:** lua/plugins/editor.lua:535-547
**Tags:** quickfix, refactor, ui

## Scope
Replaces the default quickfix rendering with a column-aligned, icon-decorated view, and makes the quickfix buffer itself editable — edits are persisted back to the underlying files on `:w`. Adds `>` / `<` to expand/collapse surrounding lines around each entry for context.

## Install spec
```lua
{
  "stevearc/quicker.nvim",
  event = "FileType qf",
  opts = {
    keys = {
      { ">", function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end, desc = "Expand qf context" },
      { "<", function() require("quicker").collapse() end, desc = "Collapse qf context" },
    },
  },
  keys = {
    { "<leader>xQ", function() require("quicker").toggle() end, desc = "Toggle quickfix (quicker)" },
  },
}
```

## Common customizations
- `opts.edit.enabled` *(bool, true)* — allow editing the qf buffer; saves rewrite files.
- `opts.edit.autosave` *(string|bool, "unchanged")* — `true` always save, `false` never, `"unchanged"` only when buffer is unmodified externally.
- `opts.borders` *(table)* — border glyphs around the qf list (`vert`, `strong_header`, …).
- `opts.highlight.treesitter` *(bool, true)* — colour lines with treesitter.
- `opts.highlight.lsp` *(bool, true)* — overlay LSP semantic tokens.
- `opts.highlight.load_buffers` *(bool, true)* — load source buffers for highlighting.
- `opts.trim_leading_whitespace` *(string|bool, "common")* — `"common"`, `"all"`, or `false`.
- `opts.max_filename_width` *(number|function)* — cap filename column.
- `opts.type_icons` *(table)* — icon per severity (`E`, `W`, `I`, `N`, `H`).
- `opts.keys` *(list)* — buffer-local keymaps active inside the qf window.
- `opts.on_qf` *(function)* — callback when the qf window opens.

## Our config
- Buffer-local `>` and `<` for context expand/collapse (2 lines each side, additive).
- Global `<leader>xQ` to toggle the quickfix window.
- All other opts default.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>xQ` | n | `require("quicker").toggle()` | Toggle quickfix window |
| `>` | n (in qf) | `expand({ before=2, after=2, add_to_existing=true })` | Show 2 more lines context around each entry |
| `<` | n (in qf) | `collapse()` | Remove context lines |

## Links
- README: https://github.com/stevearc/quicker.nvim/blob/master/README.md
- Default opts: https://github.com/stevearc/quicker.nvim/blob/master/lua/quicker/config.lua

## Notes
- Pairs naturally with `nvim-bqf` (editor.lua:197) — bqf adds preview + fzf filter; quicker handles render + edit.
- Which-key labels `<leader>x` as the `diagnostics` group (editor.lua:298).
- Save (`:w`) inside the qf buffer to apply edits to all referenced files at once.
