# lsp-trouble
> Pretty diagnostics / references / quickfix list in a dedicated window.

**Repo:** https://github.com/folke/trouble.nvim
**Local spec:** lua/plugins/lsp.lua:250-257
**Tags:** lsp, diagnostics, quickfix, ui

## Scope

Trouble aggregates diagnostics, LSP references/definitions/implementations, quickfix, location list, and `:Telescope`-style results into a sortable, foldable side panel. We use it primarily as the diagnostics viewer bound to `<leader>xx`.

## Install spec
```lua
{
  "folke/trouble.nvim",
  cmd = "Trouble",
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
  },
  config = true,
}
```

Lazy-loaded on `:Trouble` or the keymap.

## Common customizations
- `modes` *(table)* — define named views (`diagnostics`, `symbols`, `lsp_references`, etc.) with filters and sorters.
- `auto_open` / `auto_close` *(boolean, `false`)* — open/close as diagnostics appear/clear.
- `auto_preview` *(boolean, `true`)* — preview the source line under cursor.
- `focus` *(boolean, `false`)* — focus the Trouble window after `:Trouble` runs.
- `keys` *(table)* — buffer-local keymap overrides inside the Trouble window.
- `icons` *(table)* — icon set for severity, folder, kind.
- `win` *(table)* — `{ type = "split", relative = "win", position = "bottom", size = 0.3 }`.

(See https://github.com/folke/trouble.nvim/blob/main/README.md#-setup.)

## Our config

- `config = true` — accept defaults. Only `<leader>xx` is mapped.
- Other trouble modes (`symbols`, `lsp`, `loclist`, `qflist`) are reachable via `:Trouble <mode>` on demand.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>xx` | n | `:Trouble diagnostics toggle` | Toggle workspace diagnostics |
| `q` | n | (default in Trouble win) | Close |
| `<cr>` | n | (default in Trouble win) | Jump to item |
| `?` | n | (default in Trouble win) | Show help |

## Links
- README: https://github.com/folke/trouble.nvim
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)

## Notes

`<leader>xq` / `<leader>xl` (in keymaps.lua) still toggle the built-in quickfix and location list — Trouble is intentionally limited to diagnostics here.
