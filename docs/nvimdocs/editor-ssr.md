# editor-ssr
> Treesitter-powered structural search and replace — match by AST pattern, not regex.

**Repo:** https://github.com/cshuaimin/ssr.nvim
**Local spec:** lua/plugins/editor.lua:507-532
**Tags:** refactor, treesitter, search, replace

## Scope
Opens a floating prompt for a code pattern using treesitter captures (`$name` wildcards). Matches the pattern across the buffer as syntax nodes, lets you step through hits with `n`/`N`, and confirms or applies replacements interactively. Far safer than regex for refactors involving balanced braces, expressions, or multi-line constructs.

## Install spec
```lua
{
  "cshuaimin/ssr.nvim",
  keys = {
    { "<leader>cS", function() require("ssr").open() end, mode = { "n", "x" }, desc = "Structural replace (SSR)" },
  },
  opts = {
    border = "rounded",
    min_width = 50,
    min_height = 5,
    max_width = 120,
    max_height = 25,
    adjust_window = true,
    keymaps = {
      close = "q",
      next_match = "n",
      prev_match = "N",
      replace_confirm = "<cr>",
      replace_all = "<leader><cr>",
    },
  },
}
```

## Common customizations
- `border` *(string, "rounded")* — float border style; any `:help nvim_open_win` value.
- `min_width` / `min_height` *(number, 50 / 5)* — initial float dimensions.
- `max_width` / `max_height` *(number, 120 / 25)* — caps when `adjust_window=true`.
- `adjust_window` *(bool, true)* — auto-resize float to fit pattern.
- `keymaps.close` *(string, "q")* — close the SSR prompt.
- `keymaps.next_match` / `prev_match` *(string, "n"/"N")* — step through hits.
- `keymaps.replace_confirm` *(string, "<cr>")* — replace current match.
- `keymaps.replace_all` *(string, "<leader><cr>")* — replace every match.

## Our config
All options explicitly set to the upstream defaults except `max_width=120` (slightly wider) — kept here for transparency.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>cS` | n / x | `require("ssr").open()` | Open structural replace prompt |
| `q` | n (in SSR float) | close | Close prompt |
| `n` / `N` | n (in SSR float) | next/prev match | Step matches |
| `<cr>` | n (in SSR float) | replace_confirm | Replace current match |
| `<leader><cr>` | n (in SSR float) | replace_all | Replace all matches |

## Links
- README: https://github.com/cshuaimin/ssr.nvim/blob/main/README.md

## Notes
- Use `$name` to capture an arbitrary subtree, then reference `$name` in the replacement.
- Requires treesitter parser for the buffer's filetype.
- Which-key labels `<leader>c` as the `code` group (editor.lua:299).
