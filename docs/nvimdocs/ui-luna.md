# ui-luna
> Colorscheme + the transparency and contrast contract: transparent editor, solid overlays.

**Repo:** https://github.com/WTFox/luna.nvim
**Local spec:** lua/plugins/ui.lua:3
**Tags:** colorscheme, ui, transparency, highlights, contrast

## Scope

luna is a Lua colorscheme configured through `require("luna").setup(opts)`, called **before**
`:colorscheme luna` (the highlight tables are built from the config at setup time). The spec also
applies a set of post-load highlight overrides that encode a single rule: **the editor is
transparent, overlays are not.**

Replaced moonfly (bluz71/vim-moonfly-colors) in Sep 2026, backported from the nvim-vanilla
config. The contract below is unchanged; only the palette and the mechanics of getting there are.

## Install spec

```lua
{
  "WTFox/luna.nvim",
  name = "luna",
  priority = 1000,
  lazy = false,
  config = function()
    require("luna").setup({ transparent = true })
    vim.cmd.colorscheme("luna")
    -- + transparent_groups loop, the float surface and contrast overrides, below
  end,
}
```

## Common customizations

`setup()` opts (see `lua/luna/config.lua` upstream):

- `transparent` *(bool, false)* — clears backgrounds for a translucent terminal. Unlike moonfly,
  this clears **every** background, `NormalFloat` included; see below.
- `styles` — per-group italic/bold toggles (comments, keywords, functions, …).
- `overrides` — a highlight table merged into the theme's own. Not used here: the overrides in
  this config have to survive a `:colorscheme` re-run anyway, so they live in the `ColorScheme`
  autocmd instead.

Palette values are readable at `require("luna.palette")`.

## Our config

### Transparent groups

Backgrounds are force-cleared on: `Normal`, `NormalNC`, `SignColumn`, `StatusLine`,
`StatusLineNC`, `WinSeparator`. `link = false` on the `nvim_get_hl` read is load-bearing — a
linked group returns `{ link = "Target" }` and `nvim_set_hl` drops every other attribute when a
link is present, so `bg = "NONE"` was silently ignored.

### The float surface

`NormalFloat` is **set, not cleared** — this is the one real difference from the moonfly setup.
moonfly kept floats on its own `grey13` `#212121` even in transparent mode; luna's `transparent`
clears them too, and a see-through float renders hover docs, the blink.cmp menu and every picker
on top of live buffer text. So the surface is put back explicitly at luna's `bg_soft` `#1f1f1f`,
with the chrome painted flush into it:

| Group | Value | Why |
|---|---|---|
| `NormalFloat` | bg `#1f1f1f` | the solid overlay body |
| `FloatBorder` | `#1f1f1f` on `#1f1f1f` | border keeps its cell (the padding is what makes a float readable over code) but draws no frame |
| `FloatBorderTransparent` | `#1f1f1f` on `#1f1f1f` | the group snacks/telescope/fzf/notify/dap-ui/mini resolve through; without it they wear a see-through ring around a solid body |
| `FloatTitle` | bg `#1f1f1f`, fg `#c7c7c7` | otherwise a lighter chip welded onto the top border |
| `SnacksPicker` | → `NormalFloat` | picker windows resolve their body through `SnacksPicker` → `Normal`, whose bg the loop above clears |
| `SnacksPickerInputBorder` | → `SnacksPickerBorder` | the one border that does not already route there, so the prompt alone wore a different frame |
| `SnacksPickerTitle` | → `FloatTitle` | linked to `Dimmed` (bg NONE) while the matching footer sat on the surface |

All snacks groups are registered with `default = true`, so these explicit definitions win
regardless of load order.

### Contrast overrides

Measured against the real terminal background (Ghostty is `background = 000000`):

| Group | luna default | Override | Why |
|---|---|---|---|
| `WinSeparator` | fg `#1c1c1c` | fg `#404040` (luna `border`) | 28/255 from black — the split boundary vanished. Same color as `FloatBorder`, so borders and splits read alike. |
| `ColorColumn` | `#000000` | `#262626` | invisible once `Normal` is `bg=NONE`. Must also clear `CursorLine` (`#212121`) or the rule vanishes on the cursor's own line — the line you are usually measuring. |
| `TreesitterContext` | — | `#262626` | one step above the float surface: it sits directly against buffer text with no border or gap (treesitter-context renders into a plain float, no padding option). |
| `TreesitterContextLineNumber` / `*Bottom` | — | `#262626` / fg `#7c7c7c` | match the bar; `*Bottom` carries no underline (render.lua underlines the last row unconditionally and the `sp` is not honoured). |
| `LspInlayHint` | fg `#7c7c7c` | `bg=NONE`, fg `#7c7c7c`, italic | hints read as annotations, not boxed text |
| `WinBar` / `WinBarNC` | — | `bg=NONE`, fg `#c7c7c7` / `#7c7c7c` | a filled strip read as a bar welded across every window and merged into the sticky context below it; lualine paints its own section bg, hence the matching clears in the winbar components |

Diagnostic underline **styles** (undercurl / underdouble / underdotted / underdashed per
severity) are set in `lua/plugins/lsp.lua`, not here, because they are re-applied on
`ColorScheme` — see [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md).

### Re-application

Every override above runs once after `:colorscheme luna` and again from a `ColorScheme` autocmd
(`pattern = "luna"`), because any re-run of the colorscheme restores luna's own definitions.

### Semantic token priority

`lua/config/options.lua` sets `vim.hl.priorities.semantic_tokens = 95`. Treesitter extmarks are
priority 100 and LSP semantic tokens default to 125, so `@lsp.type.*` overpainted every
treesitter capture it overlapped — LSP-attached buffers looked flatter than the same file with
the server stopped (neovim/neovim#33614, still open, no per-language knob). Demoting tokens below
treesitter keeps them only where treesitter has nothing to say.

## Keymaps

None.

## Links

- README: https://github.com/WTFox/luna.nvim/blob/main/README.md
- Terminal side of transparency: [terminal-ghostty-tmux](terminal-ghostty-tmux.md)
- Related: [config-options](config-options.md), [ui-lualine](ui-lualine.md), [ts-context](ts-context.md), [ui-tiny-inline-diagnostic](ui-tiny-inline-diagnostic.md)

## Notes

- **Transparency does nothing without the terminal.** `transparent = true` only shows if
  Ghostty's `background-opacity` is uncommented — see
  [terminal-ghostty-tmux](terminal-ghostty-tmux.md).
- lualine's theme is `"auto"` now: lualine ships a `moonfly` theme but none for luna, and the bar
  is transparent anyway — see [ui-lualine](ui-lualine.md).
- The overrides are hex-pinned rather than read from `require("luna.palette")` so the numbers are
  visible at the point of use; if the theme's greys change, re-measure rather than assuming these
  still contrast.
