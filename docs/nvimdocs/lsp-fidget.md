# lsp-fidget
> Floating LSP progress + notification UI in the bottom-right corner.

**Repo:** https://github.com/j-hui/fidget.nvim
**Local spec:** lua/plugins/lsp.lua:257
**Tags:** lsp, progress, notify, ui

## Scope

Fidget renders `$/progress` LSP messages (e.g. "intelephense indexing 1234/5678") and `vim.notify` notifications in a non-intrusive floating window. We use it both as the LSP progress indicator and as a global `vim.notify` backend.

## Install spec
```lua
{
  "j-hui/fidget.nvim",
  event = "LspAttach",
  opts = {
    progress = {
      display = {
        render_limit = 5,
        done_ttl = 2,
      },
    },
    notification = {
      window = {
        winblend = 0, -- solid background for catppuccin
      },
    },
  },
}
```

Lazy-loaded on `LspAttach` so it only starts once an LSP client is actually attached.

## Common customizations
- `progress.display.render_limit` *(integer, `16`)* — max concurrent progress lines shown.
- `progress.display.done_ttl` *(integer, `3`)* — seconds to keep a completed task visible.
- `progress.display.progress_icon` / `done_icon` *(string)* — leading icons.
- `progress.poll_rate` *(integer, `0`)* — refresh hz; `0` = on-demand.
- `progress.ignore` *(string[], `{}`)* — LSP client names to suppress.
- `notification.window.winblend` *(integer, `100`)* — 0 = opaque, 100 = transparent.
- `notification.window.border` *(string, `"none"`)* — border style.
- `notification.override_vim_notify` *(boolean, `false`)* — replace `vim.notify`.
- `integration.nvim-tree.enable` *(boolean, `true`)* — offset around nvim-tree.

(See https://github.com/j-hui/fidget.nvim/blob/main/doc/fidget.txt.)

## Our config

- `render_limit = 5` — keep the stack short; large LSPs (intelephense, ts_ls) emit many concurrent tasks.
- `done_ttl = 2` — fade completed tasks quickly.
- `winblend = 0` — the catppuccin theme looks washed out at the default winblend.

## Keymaps

None — pure UI, no keybindings.

## Links
- README: https://github.com/j-hui/fidget.nvim
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)

## Notes

`vim.notify` override is left at its default (`false`); we use `snacks.nvim` (or built-in) for general notifications. Fidget here is scoped to LSP progress.
