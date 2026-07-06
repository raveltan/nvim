# ui-gruvbox-baby

> ⚠️ **REMOVED** — plugin is no longer in this config (colorscheme no longer installed). Doc kept for history.
> Warm gruvbox-derived dark colorscheme; loaded eagerly with high priority and patched for terminal transparency.

**Repo:** https://github.com/luisiacc/gruvbox-baby
**Local spec:** lua/plugins/ui.lua:4-25
**Tags:** colorscheme, theme, transparency

## Scope
Sets `gruvbox-baby` as the active colorscheme at startup and forces a transparent background by clearing `bg` on a curated list of highlight groups (Normal, NormalNC, NormalFloat, SignColumn, StatusLine*, FloatBorder, WinSeparator). Designed to coexist with a transparent terminal.

## Install spec
```lua
{
  "luisiacc/gruvbox-baby",
  priority = 1000,
  lazy = false,
  config = function()
    vim.cmd.colorscheme("gruvbox-baby")
    -- clear bg on transparent_groups
  end,
}
```

## Common customizations
All options are `vim.g.gruvbox_baby_*` globals; **must be set before `:colorscheme`**.

- `gruvbox_baby_background_color` *(string, `"medium"`)* — palette intensity. `"medium"` or `"dark"`.
- `gruvbox_baby_transparent_mode` *(bool, `false`)* — sets all bg to NONE upstream. We do this manually for finer control.
- `gruvbox_baby_comment_style` *(string, `"italic"`)* — any `:h attr-list` value.
- `gruvbox_baby_keyword_style` *(string, `"italic"`)*.
- `gruvbox_baby_string_style` *(string, `"nocombine"`)*.
- `gruvbox_baby_function_style` *(string, `"bold"`)*.
- `gruvbox_baby_variable_style` *(string, `"NONE"`)*.
- `gruvbox_baby_highlights` *(table, `{}`)* — override individual highlight groups.
- `gruvbox_baby_color_overrides` *(table, `{}`)* — override palette colors by name.
- `gruvbox_baby_use_original_palette` *(bool, `false`)* — switch to upstream gruvbox palette.
- `gruvbox_baby_telescope_theme` *(bool, `false`)* — enable themed Telescope highlights.

## Our config
- `priority = 1000`, `lazy = false` — load first so dependent plugins see the palette.
- After `colorscheme`, we iterate `transparent_groups` and `nvim_set_hl(0, group, { bg = "NONE", ... })`, merging with the current hl so fg/styles stay intact.
- We do **not** set `gruvbox_baby_transparent_mode`; the manual approach lets us pick exactly which groups go transparent.

## Keymaps
None.

## Links
- README: https://github.com/luisiacc/gruvbox-baby/blob/main/README.md
- Palette: https://github.com/luisiacc/gruvbox-baby/blob/main/lua/gruvbox-baby/colors.lua

## Notes
- The transparency patch runs once at startup. If you later `:colorscheme` something else and back, the patch is lost — re-run `:source` of the plugin spec or wrap the patch in a `ColorScheme` autocmd.
- Lualine theme is also `"gruvbox-baby"` (see ui-lualine.md); changing colorscheme requires updating lualine's `options.theme` too.
- Floating-window borders inherit `FloatBorder` bg = NONE, which combined with `vim.o.winborder = "rounded"` gives borderless-on-terminal look while keeping the rounded glyph.
