# ts-textobjects
> Treesitter-powered text objects, motions, swaps, and incremental selection.

**Repo:** https://github.com/nvim-treesitter/nvim-treesitter-textobjects
**Local spec:** lua/plugins/treesitter.lua:57-130
**Tags:** treesitter, textobjects, motions, selection

## Scope
Adds query-driven text objects (function, class, parameter) usable in operator-pending and visual modes, plus motion mappings to jump between them and a swap module for arg/element reordering. Also wires a hand-rolled incremental selection that expands/shrinks by syntax node.

## Install spec
```lua
{
  "nvim-treesitter/nvim-treesitter-textobjects",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = { lookahead = true },
    })
    -- per-key map() calls into select/move/swap modules
  end,
}
```

## Common customizations
- `select.lookahead` *(boolean, default `false`)* — auto-jump forward to next textobject if cursor isn't on one (targets.vim-style).
- `select.selection_modes` *(table, default `{}`)* — per-query selection mode override (`'v'`, `'V'`, `'<c-v>'`).
- `select.include_surrounding_whitespace` *(boolean, default `false`)* — extend selection over leading/trailing whitespace.
- `move.set_jumps` *(boolean, default `true`)* — record motions in the jumplist.

## Our config
- `select = { lookahead = true }` — leans on lookahead so `vif` etc. works even when the cursor sits before a function body.
- Mappings called explicitly per key via `select.select_textobject`, `move.goto_next_start`/`goto_previous_start`, `swap.swap_next`/`swap.swap_previous` — no module-level `keymaps = {...}` block.
- Query file used everywhere: `"textobjects"` (i.e. `queries/<lang>/textobjects.scm`).

## Keymaps
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `af` | x, o | `select @function.outer` | Around function |
| `if` | x, o | `select @function.inner` | Inside function |
| `ac` | x, o | `select @class.outer` | Around class |
| `ic` | x, o | `select @class.inner` | Inside class |
| `aa` | x, o | `select @parameter.outer` | Around argument |
| `ia` | x, o | `select @parameter.inner` | Inside argument |
| `]f` | n, x, o | `goto_next_start @function.outer` | Next function |
| `[f` | n, x, o | `goto_previous_start @function.outer` | Prev function |
| `]a` | n, x, o | `goto_next_start @parameter.outer` | Next argument |
| `[a` | n, x, o | `goto_previous_start @parameter.outer` | Prev argument |
| `<leader>csa` | n | `swap.swap_next @parameter.inner` | Swap arg with next |
| `<leader>csA` | n | `swap.swap_previous @parameter.inner` | Swap arg with prev |
| `<CR>` | n | start incremental select (current node) | Begin node selection |
| `<CR>` | x | expand to parent node | Grow selection |
| `<BS>` | x | shrink to child node at cursor | Shrink selection |

## Links
- README: https://github.com/nvim-treesitter/nvim-treesitter-textobjects/blob/main/README.md
- Related: [ts-nvim-treesitter](ts-nvim-treesitter.md)

## Notes
- The incremental selection block is custom (not the upstream `incremental_selection` module). It stashes the current node in a closure-local `current_node` and uses `nvim_buf_set_mark` + `gv` to drive the visual range.
- Mark column for the end (`>`) is `ec - 1` to compensate for treesitter's exclusive end column vs vim's inclusive visual mark.
- No `<C-Space>` / `grn` style upstream defaults are bound — `<CR>` and `<BS>` replace them.
