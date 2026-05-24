# ui-edgy
> Pins sidebar and bottom-panel windows to deterministic positions so trouble, qf, dap-view, undotree, etc. always land in the right slot.

**Repo:** https://github.com/folke/edgy.nvim
**Local spec:** lua/plugins/edgy.lua:1-83
**Tags:** ui, layout, sidebar, panels

## Scope
Solves the "where did that quickfix window open?" problem by intercepting window creation for specific filetypes and routing them into named edgebars (bottom/left/right/top). Each edgebar can hold multiple groups; switching between them is tab-like. We pin a bottom panel for diagnostics/run output and a left panel for undo history.

## Install spec
```lua
{
  "folke/edgy.nvim",
  event = "VeryLazy",
  init = function()
    vim.opt.laststatus = 3
    vim.opt.splitkeep = "screen"
  end,
  opts = {
    animate = { enabled = false },
    wo = {
      winbar = true,
      winfixwidth = true,
      winfixheight = false,
      winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
      spell = false,
    },
    exit_when_last = true,
    close_when_all_hidden = true,
    bottom = { trouble, qf, dap-repl, dap-view, dap-view-term, help, grug-far },
    left   = { undotree, diff },
    keys   = { q, <c-q>, Q },
  },
}
```

## Common customizations
- `animate.enabled` *(bool, true)* — slide-in animation. Disabled here (smear-cursor + indentscope already animate).
- `wo.winbar` *(bool, true)* — title bar per edgy window.
- `wo.winfixwidth` / `wo.winfixheight` *(bool)* — lock dimensions against `<C-w>=`.
- `wo.winhighlight` *(string)* — remap `Normal`/`WinBar` to edgy-specific groups for theming.
- `exit_when_last` *(bool, false)* — `:q` the last real window exits Neovim even if edgy panels remain.
- `close_when_all_hidden` *(bool, true)* — close the edgebar frame when every child is hidden.
- `bottom` / `left` / `right` / `top` *(table[])* — group definitions. Each item is `{ ft, title?, size?, filter?, open?, pinned?, ... }`.
- `size.height` / `size.width` *(number | float 0..1)* — absolute lines/cols or fraction of editor.
- `filter` *(fun(buf, win) → bool)* — extra predicate beyond `ft`.
- `open` *(string|fun)* — command to spawn the buffer when the slot is empty (e.g. `"UndotreeToggle"`).
- `pinned` *(bool, false)* — keep the slot visible even when empty.
- `keys` *(table)* — per-edgy-window keymaps (the `win` arg has `:close()`, `:hide()`, `.view.edgebar`).
- `options.left.size` etc. — global per-edge defaults.

WebFetch https://raw.githubusercontent.com/folke/edgy.nvim/HEAD/README.md for the full schema.

## Our config
- `init` sets `laststatus = 3` (single global statusline, already required by lualine) and `splitkeep = "screen"` so cursor position doesn't jump when edgy resizes splits.
- `animate = false` — avoid double-animation with smear-cursor.
- `wo`: `winbar=true`, `winfixwidth=true`, `winfixheight=false` (heights flex), custom highlights, `spell=false` (no red squiggles in panel buffers).
- `exit_when_last = true`, `close_when_all_hidden = true` — clean exit semantics.

### bottom panels
- `trouble` — Trouble diagnostics list, 30% height.
- `qf` — built-in quickfix, 25%.
- `dap-repl` — nvim-dap REPL, 30%.
- `dap-view` — nvim-dap-view main panel, 35%.
- `dap-view-term` — dap-view terminal, 30%.
- `help` — `:h` windows, 40%, with a `filter` guarding `vim.bo[buf].buftype == "help"` so non-help `ft=help` buffers don't get captured.
- `grug-far` — search/replace UI, 40%.

### left panels
- `undotree` — 30 cols wide, `pinned=false`, `open = "UndotreeToggle"` so the slot lazy-spawns the plugin.
- `diff` — undotree's diff preview, 40% height (sits below undotree on the left edge).

### keys (inside edgy windows)
| Key | Action | Desc |
|---|---|---|
| `q` | `win:close()` | Close just this view |
| `<C-q>` | `win:hide()` | Hide (slot persists if pinned) |
| `Q` | `win.view.edgebar:close()` | Close the whole edgebar |

## Links
- README: https://github.com/folke/edgy.nvim/blob/main/README.md
- Recipes: https://github.com/folke/edgy.nvim#-examples
- Default opts: https://github.com/folke/edgy.nvim/blob/main/lua/edgy/config.lua

## Notes
- `laststatus = 3` is mandatory — edgy assumes one global statusline.
- The `help` filter guards against buffers that set `ft=help` but aren't actual help (e.g. some preview plugins); without it they'd be captured into the bottom panel.
- `undotree` uses `pinned = false` and an `open` command so the slot only exists while the plugin is active; the `diff` slot fills in once undotree opens its preview.
- Filetypes listed here must also appear in `satellite.nvim`'s `excluded_filetypes` (they do) to keep the scrollbar from overlaying panel UI.
- DAP view + REPL + terminal can all be open simultaneously; edgy tabs them in the bottom edgebar.
