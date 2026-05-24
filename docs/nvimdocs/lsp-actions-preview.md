# lsp-actions-preview
> Preview LSP code actions as a diff before applying.

**Repo:** https://github.com/aznhe21/actions-preview.nvim
**Local spec:** lua/plugins/lsp.lua:241-247
**Tags:** lsp, code-action, preview, telescope

## Scope

Replaces the default `vim.lsp.buf.code_action()` picker with one that shows a diff of the edit each action would apply. The picker backend auto-detects telescope / snacks / mini.pick / `vim.ui.select`. We bind it to `<leader>ca`; the raw `vim.lsp.buf.code_action()` is still available via the Neovim 0.11 default `gra`.

## Install spec
```lua
{
  "aznhe21/actions-preview.nvim",
  keys = {
    { "<leader>ca", function() require("actions-preview").code_actions() end,
      mode = { "n", "v" }, desc = "Code action (preview)" },
  },
  opts = {},
}
```

Lazy-loaded on the first `<leader>ca` press.

## Common customizations
- `diff` *(table)* — passed to `vim.diff()`; e.g. `{ ctxlen = 3, algorithm = "patience" }`.
- `highlight_command` *(table)* — preview highlighter (`require('actions-preview.highlight').delta()` / `diff_so_fancy()` / `diff_highlight()`).
- `backend` *(string[], `{ "telescope", "nui", "snacks" }`)* — picker priority.
- `telescope` / `nui` / `snacks` *(table)* — backend-specific opts (layout, mappings, …).

(See https://github.com/aznhe21/actions-preview.nvim#configuration.)

## Our config

- `opts = {}` — accept defaults. Backend resolves to snacks-picker because [snacks-picker](snacks-picker.md) is installed.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>ca` | n, v | `actions-preview.code_actions()` | Code action with diff preview |
| `gra` | n | (Neovim default) `vim.lsp.buf.code_action` | Raw code action picker (no preview) |

## Links
- README: https://github.com/aznhe21/actions-preview.nvim
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)

## Notes

Visual mode is supported — selecting a range and pressing `<leader>ca` asks the server for range code actions (organise imports on a slice, extract method, etc.).
