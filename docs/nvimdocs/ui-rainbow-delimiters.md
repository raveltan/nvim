# ui-rainbow-delimiters
> Treesitter-based rainbow brackets/parentheses; default config plus a 1500-line size guard.

**Repo:** https://github.com/HiPhish/rainbow-delimiters.nvim
**Local spec:** lua/plugins/ui.lua:155
**Tags:** treesitter, brackets, ui

## Scope
Colors matching delimiter pairs (`()`, `[]`, `{}`, etc.) by nesting depth using Treesitter queries. Loads on `BufReadPost`. Skips attach per-buffer when line count exceeds 1500 to avoid extmark cost on big files.

## Install spec
```lua
{
  "HiPhish/rainbow-delimiters.nvim",
  event = "BufReadPost",
  config = function()
    require("rainbow-delimiters.setup").setup({
      condition = function(buf)
        return vim.api.nvim_buf_line_count(buf) <= 1500
      end,
    })
  end,
}
```

## Common customizations
All keys accept either a single value or a per-filetype table keyed by `&filetype`, with `[""]` as the default. Set via `require("rainbow-delimiters.setup").setup({...})` or `vim.g.rainbow_delimiters = {...}`.

- `strategy` *(table)* — when to (re)highlight. Default `["" ] = require("rainbow-delimiters").strategy.global`. Alternative: `.strategy.local` (only the scope around cursor) or `.strategy.noop` (disable).
- `query` *(table)* — name of the Treesitter query file. Default `[""] = "rainbow-delimiters"`. Alternatives include `"rainbow-blocks"` (also colors block keywords), `"rainbow-parens"`.
- `priority` *(table, default `200`)* — extmark priority per filetype.
- `highlight` *(list of strings)* — highlight groups used in rotation. Default: `RainbowDelimiterRed`, `RainbowDelimiterYellow`, `RainbowDelimiterBlue`, `RainbowDelimiterOrange`, `RainbowDelimiterGreen`, `RainbowDelimiterViolet`, `RainbowDelimiterCyan`.
- `blacklist` *(list of filetype strings, `{}`)* — disable entirely for these filetypes.
- `whitelist` *(list of filetype strings, nil)* — when set, only these filetypes get rainbows.

- `condition` *(function(bufnr) -> bool)* — checked at attach time; return false to skip the buffer entirely.

Per-buffer disable after attach: `require("rainbow-delimiters").disable(bufnr)` / `.toggle(bufnr)`. (There is NO `vim.b.rainbow_delimiters_disable` flag — that pattern belongs to mini.indentscope.)

## Our config
- `setup({ condition = ... })` — defaults (global strategy, `rainbow-delimiters` query, default highlight rotation) plus a `condition` hook that skips attach for buffers over 1500 lines. Same intent as the mini.indentscope / hlargs guards, but via the plugin's own API.

## Keymaps
None.

## Links
- Upstream: https://gitlab.com/HiPhish/rainbow-delimiters.nvim
- README (mirror): https://github.com/HiPhish/rainbow-delimiters.nvim
- Help: `:help rainbow-delimiters`

## Notes
- Requires the corresponding Treesitter parser for each language; without a parser the file is skipped silently.
- The 1500-line `condition` is evaluated once at attach (FileType) — a buffer that grows past 1500 lines afterwards keeps its highlights; disable manually with `:lua require("rainbow-delimiters").disable(0)`.
- Highlight group colors come from the active colorscheme; `gruvbox-baby` provides them. To recolor, override the seven `RainbowDelimiter*` groups via `vim.api.nvim_set_hl`.
