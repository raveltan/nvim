# ui-satellite
> Decorated scrollbar in the right gutter showing marks, gitsigns, diagnostics, cursor, search, and quickfix positions.

**Repo:** https://github.com/lewis6991/satellite.nvim
**Local spec:** lua/plugins/ui.lua:195
**Tags:** ui, scrollbar, gitsigns, diagnostics, marks

## Scope
Replaces the lack of a native Neovim scrollbar with a minimap-style indicator. Pluggable "handlers" overlay extra information on the bar: cursor position, search hits, diagnostic severity ticks, gitsigns add/change/delete, user marks, and quickfix entries. We restrict it to text buffers and tint the bar to match a transparent theme.

## Install spec
```lua
{
  "lewis6991/satellite.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "lewis6991/gitsigns.nvim" },
  opts = {
    current_only = true,
    winblend = 50,
    zindex = 40,
    excluded_filetypes = { "dashboard", "help", "lazy", "trouble", "oil", "noice", ... },
    handlers = {
      cursor     = { enable = true, overlap = true, priority = 1000 },
      search     = { enable = true, overlap = true, priority = 10 },
      diagnostic = { enable = true, signs = { "-", "=", "≡" }, min_severity = vim.diagnostic.severity.WARN },
      gitsigns   = { enable = true, signs = { add = "│", change = "│", delete = "-" } },
      marks      = { enable = true, show_builtins = false, key = "m" },
      quickfix   = { enable = true, signs = { "-", "=", "≡" } },
    },
  },
}
```

## Common customizations
- `current_only` *(bool, false)* — only render the bar in the focused window. We enable it to reduce visual noise across splits.
- `winblend` *(int, 50)* — transparency of the bar window (0 opaque, 100 invisible).
- `zindex` *(int, 40)* — float z-index; raise above other floats if they cover the bar.
- `excluded_filetypes` *(string[])* — filetypes that should never show the bar (dashboards, sidebars, special panels).
- `handlers.cursor` *(table)* — small dot for the cursor row.
- `handlers.search` *(table)* — marks for `hlsearch` matches.
- `handlers.diagnostic.signs` *(string[3])* — glyphs for stacking density.
- `handlers.diagnostic.min_severity` *(severity, HINT)* — minimum severity to draw. We raise to `WARN` to skip hint/info noise.
- `handlers.gitsigns.signs` *(table)* — per-status glyphs; `delete` uses a short dash since deletions are line-less.
- `handlers.marks.show_builtins` *(bool, false)* — show `[` `]` `<` `>` and friends in addition to user marks.
- `handlers.marks.key` *(string, "m")* — refresh key after `m<x>` to draw the new mark.
- `handlers.quickfix` *(table)* — overlay current quickfix list entries.

## Our config
- `current_only = true`, `winblend = 50` — minimalist, blends with transparent theme.
- Broad `excluded_filetypes` covering trouble, oil, dap-view, noice, grug-far, fugitive, markview, avante — these own their own rendering and conflict with the satellite float.
- `ColorScheme` autocmd sets `SatelliteBar` bg to `#30363d` (GitHub dark grey) and clears `SatelliteBackground`, so the bar is visible on transparent backgrounds. Re-applied immediately via `pcall` so the first paint after startup is correct.
- `diagnostic.min_severity = WARN` — only warnings and errors appear in the bar; hints/info would otherwise saturate it on LSP-heavy buffers.

## Keymaps
None bound. Toggle via `:SatelliteEnable` / `:SatelliteDisable` / `:SatelliteRefresh`.

## Links
- README: https://github.com/lewis6991/satellite.nvim/blob/main/README.md
- Default config: https://github.com/lewis6991/satellite.nvim/blob/main/lua/satellite/default_config.lua
- Highlight groups: `:h satellite-highlights`

## Notes
- Handler `priority` controls draw order on overlap; cursor at 1000 always wins over search/diagnostic ticks.
- `overlap = true` lets cursor/search share rows with other handlers instead of being suppressed.
- Excluded filetypes must include both casings (`trouble` and `Trouble`) since plugins set ft inconsistently.
- The bar is a regular floating window — `zindex` interactions with noice/nui floats can hide it; bump zindex if it disappears under hover popups.
