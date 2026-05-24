# ui-lualine
> Statusline with global mode/git/diagnostics, conditional encoding/fileformat, macro-recording indicator, and active LSP clients.

**Repo:** https://github.com/nvim-lualine/lualine.nvim
**Local spec:** lua/plugins/ui.lua:42-111
**Tags:** statusline, ui, lsp, git

## Scope
Configures a single global statusline (one bar across all splits) themed to `gruvbox-baby`. Adds two custom components — a red `REC @x` macro indicator and an LSP-clients list — plus conditional `encoding`/`fileformat` components that only render when non-default. Disabled on dashboard-like buffers.

## Install spec
```lua
{
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "echasnovski/mini.icons" },
  opts = function() ... end,
}
```

## Common customizations
Top-level `options`:
- `theme` *(string, `"auto"`)* — palette name; `"auto"` reads from current colorscheme.
- `globalstatus` *(bool, `false`)* — single statusline for all windows (requires `laststatus=3`).
- `icons_enabled` *(bool, `true`)*.
- `section_separators` *(table, `{ left = "", right = "" }`)* — outer powerline glyphs.
- `component_separators` *(table, `{ left = "", right = "" }`)* — inner separators.
- `disabled_filetypes` *(table, `{ statusline = {}, winbar = {} }`)* — skip lualine for these filetypes.
- `ignore_focus` *(list, `{}`)* — filetypes treated as unfocused for highlighting.
- `always_divide_middle` *(bool, `true`)*.
- `always_show_tabline` *(bool, `true`)*.
- `refresh` *(table)* — debounce intervals per surface plus the `events` list that triggers redraw.

Section keys: `lualine_a`/`b`/`c`/`x`/`y`/`z` for sections, `tabline`/`winbar`/`inactive_*` for other surfaces.

Standard components: `mode`, `branch`, `diff`, `diagnostics`, `filename`, `filetype`, `filesize`, `encoding`, `fileformat`, `progress`, `location`, `searchcount`, `selectioncount`, `tabs`, `buffers`, `windows`, `hostname`, `lsp_status`. Each accepts `{ <name>, icon = ..., separator = ..., padding = ..., cond = fn, color = {...}, symbols = {...} }`.

## Our config
- `theme = "gruvbox-baby"`, `globalstatus = true`, ASCII separators only (`|`).
- `disabled_filetypes.statusline = { "dashboard", "alpha", "snacks_dashboard", "starter" }` — no bar on splash screens.
- `extensions = { "lazy", "mason", "neo-tree", "trouble", "quickfix" }` — plugin-specific lualine modules.

Sections:
- **a** — `mode` with empty icon.
- **b** — `branch` (), `diff` with nf-fa add/mod/del glyphs, `diagnostics` with nf-fa severity glyphs.
- **c** — `filetype` icon-only (no label, no right padding) + `filename` (path=0 → just basename) with modified/readonly/unnamed symbols, then **macro** component.
- **x** — **lsp** component, then conditional `encoding`/`fileformat`, then `filetype` (text).
- **y** — `progress`.
- **z** — `location` with empty icon.

Custom components:
- **macro** — reads `vim.fn.reg_recording()`, prints `REC @<reg>` in `#ff5555` bold. `cond` hides it when not recording.
- **lsp** — iterates `vim.lsp.get_clients({ bufnr = 0 })`, joins names with comma, prefixed by . Empty string → component hides.
- **encoding** — `cond` only renders if `fileencoding` is set and non-`utf-8`.
- **fileformat** — `cond` only renders if `fileformat ~= "unix"`.

Autocmd: `RecordingEnter`/`RecordingLeave` → `require("lualine").refresh()` so the REC indicator appears/disappears instantly. We intentionally **dropped `ModeChanged`** — lualine already redraws on mode change internally and the extra refresh doubled work on every n↔i↔v↔c transition.

## Keymaps
None.

## Links
- README: https://github.com/nvim-lualine/lualine.nvim/blob/master/README.md
- Component docs: https://github.com/nvim-lualine/lualine.nvim/blob/master/doc/lualine.txt

## Notes
- `globalstatus = true` requires Neovim ≥ 0.7 and effectively forces `laststatus=3`; per-window statuslines are gone.
- `filetype` appears twice: once as icon-only in section **c** (left of filename) and once as text in section **x**. Intentional — icon next to name, text label on the right.
- The duplicate-refresh prevention comment in the spec is load-bearing: don't re-add `ModeChanged` to the autocmd list.
