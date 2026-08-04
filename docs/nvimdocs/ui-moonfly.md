# ui-moonfly
> Colorscheme + the transparency and contrast contract: transparent editor, solid overlays.

**Repo:** https://github.com/bluz71/vim-moonfly-colors
**Local spec:** lua/plugins/ui.lua:3
**Tags:** colorscheme, ui, transparency, highlights, contrast

## Scope

moonfly is a VimScript colorscheme configured entirely through `g:moonfly*` globals that are
read **at load time** — so every global must be set *before* `:colorscheme moonfly`, and there is
no `setup()` to call. The spec also applies a small set of post-load highlight overrides that
encode a single rule: **the editor is transparent, overlays are not.**

## Install spec

```lua
{
  "bluz71/vim-moonfly-colors",
  name = "moonfly",
  priority = 1000,
  lazy = false,
  config = function()
    vim.g.moonflyTransparent = true
    vim.cmd.colorscheme("moonfly")
    -- + transparent_groups loop and contrast overrides, below
  end,
}
```

## Common customizations

Globals (all read before the `colorscheme` command):

- `g:moonflyTransparent` *(bool, false)* — clears backgrounds for a translucent terminal. **Must
  be boolean `true`, not `1`** — some branches in the theme test `== true`, and with `1` the
  statusline/tabline stay opaque.
- `g:moonflyNormalFloat` *(bool, false)* — when true, floats use the terminal background too.
  Left **false** here on purpose; see below.
- `g:moonflyWinSeparator` *(0|1|2)* — separator style.
- `g:moonflyCursorColor`, `g:moonflyItalics`, `g:moonflyUndercurls`, `g:moonflyUnderlineMatchParen`,
  `g:moonflyVirtualTextColor`, `g:moonflyNormalPmenu`, `g:moonflyTerminalColors`.

## Our config

### Transparent groups

Backgrounds are force-cleared on: `Normal`, `NormalNC`, `SignColumn`, `StatusLine`,
`StatusLineNC`, `WinSeparator`.

`NormalFloat` and `FloatBorder` are **deliberately excluded.** moonfly's default
(`g:moonflyNormalFloat = false`) already gives floats a `grey13` `#212121` surface *even in
transparent mode*. Clearing it made hover docs, the blink.cmp menu and every picker render on top
of live buffer text. This is also what the `Snacks*` highlight groups inherit, so keeping it
solid is what makes snacks floats readable.

### Contrast overrides

Measured against the real terminal background (Ghostty is `background = 000000`):

| Group | moonfly default | Override | Why |
|---|---|---|---|
| `ColorColumn` | `#121212` | `#262626` | 18/255 from black is invisible once `Normal` is `bg=NONE`. Must also clear `CursorLine` (`#1c1c1c`) or the rule vanishes on the cursor's own line — the line you are usually measuring. |
| `TreesitterContext` | `#121212` | `#212121` | Same surface as floats, so the sticky header reads as a pinned panel rather than un-scrolled buffer text. |
| `TreesitterContextLineNumber` | — | `#212121` / fg `#6d6d6d` | match the bar |
| `LspInlayHint` | bg `#1c1c1c` | `bg=NONE`, fg `#6d6d6d`, italic | inherited bg drew a grey box floating in transparent code |

Diagnostic underline **styles** (undercurl / underdouble / underdotted / underdashed per
severity) are set in `lua/plugins/lsp.lua`, not here, because they are re-applied on
`ColorScheme` — see [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md).

### Semantic token priority

`lua/config/options.lua` sets `vim.hl.priorities.semantic_tokens = 95`. Treesitter extmarks are
priority 100 and LSP semantic tokens default to 125, so `@lsp.type.*` overpainted every
treesitter capture it overlapped — LSP-attached buffers looked flatter than the same file with
the server stopped (neovim/neovim#33614, still open, no per-language knob). Demoting tokens below
treesitter keeps them only where treesitter has nothing to say.

## Keymaps

None.

## Links

- README: https://github.com/bluz71/vim-moonfly-colors/blob/master/README.md
- Terminal side of transparency: [terminal-ghostty-tmux](terminal-ghostty-tmux.md)
- Related: [config-options](config-options.md), [ui-lualine](ui-lualine.md), [ts-context](ts-context.md), [ui-tiny-inline-diagnostic](ui-tiny-inline-diagnostic.md)

## Notes

- **Transparency does nothing without the terminal.** `moonflyTransparent` only shows if
  Ghostty's `background-opacity` is uncommented — see
  [terminal-ghostty-tmux](terminal-ghostty-tmux.md).
- moonfly is actively maintained (0.12 highlight groups added Apr 2026, ~25 plugin integrations
  incl. snacks, blink.cmp, rainbow-delimiters, treesitter-context) — the periodic "should we move
  to catppuccin/tokyonight" question was checked in Aug 2026 and answered **no**.
- The contrast overrides are hex-pinned rather than palette-derived because moonfly exposes its
  palette only through `require("moonfly").palette` after load; if the theme's greys change,
  re-measure rather than assuming these still contrast.
