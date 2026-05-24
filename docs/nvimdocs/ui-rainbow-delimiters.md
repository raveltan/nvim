# ui-rainbow-delimiters
> Treesitter-based rainbow brackets/parentheses; default config plus a 1500-line size guard.

**Repo:** https://github.com/HiPhish/rainbow-delimiters.nvim
**Local spec:** lua/plugins/ui.lua:147-159
**Tags:** treesitter, brackets, ui

## Scope
Colors matching delimiter pairs (`()`, `[]`, `{}`, etc.) by nesting depth using Treesitter queries. Loads on `BufReadPost`. Disables itself per-buffer when line count exceeds 1500 to avoid extmark cost on big files.

## Install spec
```lua
{
  "HiPhish/rainbow-delimiters.nvim",
  event = "BufReadPost",
  config = function()
    require("rainbow-delimiters.setup").setup({})
    -- BufReadPost autocmd for 1500-line guard
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

Per-buffer disable: `vim.b[bufnr].rainbow_delimiters_disable = true`.

## Our config
- `setup({})` — all defaults: global strategy, `rainbow-delimiters` query, default highlight rotation.
- `BufReadPost` autocmd: sets `vim.b[args.buf].rainbow_delimiters_disable = true` when buffer line count > 1500. Matches the same guard used by `mini.indentscope` and `hlargs.nvim`.

## Keymaps
None.

## Links
- Upstream: https://gitlab.com/HiPhish/rainbow-delimiters.nvim
- README (mirror): https://github.com/HiPhish/rainbow-delimiters.nvim
- Help: `:help rainbow-delimiters`

## Notes
- Requires the corresponding Treesitter parser for each language; without a parser the file is skipped silently.
- The 1500-line guard runs on `BufReadPost` but doesn't *undo* highlights drawn before the guard fires — for already-open big buffers, toggle with `:lua vim.b.rainbow_delimiters_disable = true` then reopen.
- Highlight group colors come from the active colorscheme; `gruvbox-baby` provides them. To recolor, override the seven `RainbowDelimiter*` groups via `vim.api.nvim_set_hl`.
