# ui-colorizer
> Inline color swatches for hex / rgb() / hsl() / named / Tailwind colors, rendered as virtual text after the value.

**Repo:** https://github.com/catgoose/nvim-colorizer.lua (maintained fork of NvChad/nvim-colorizer.lua)
**Local spec:** lua/plugins/ui.lua:170
**Tags:** colors, css, tailwind, virtualtext

## Scope
Scans buffers for color literals and draws a small colored block next to each one. We enable CSS function parsing (`rgb()`, `hsl()`, etc.) and Tailwind class detection, rendered as `virtualtext` (a colored square trailing the match) instead of recoloring the literal itself.

## Install spec
```lua
{
  "NvChad/nvim-colorizer.lua",
  event = "BufReadPost",
  opts = {
    user_default_options = {
      css = true,
      tailwind = true,
      mode = "virtualtext",
    },
  },
}
```

## Common customizations
Top-level keys passed to `setup`:
- `filetypes` *(list, `{ "*" }`)* — which filetypes to attach to. `"*"` means all.
- `buftypes` *(list, `{}`)* — restrict by `&buftype`.
- `user_default_options` *(table)* — see below.

`user_default_options` keys:
- `RGB` *(bool, `true`)* — `#rgb` short form.
- `RRGGBB` *(bool, `true`)* — `#rrggbb`.
- `RRGGBBAA` *(bool, `false`)* — `#rrggbbaa`.
- `AARRGGBB` *(bool, `false`)* — alpha-first hex.
- `names` *(bool, `true`)* — CSS named colors (`red`, `cornflowerblue`, ...).
- `rgb_fn` *(bool, `false`)* — `rgb()` / `rgba()` functional notation.
- `hsl_fn` *(bool, `false`)* — `hsl()` / `hsla()` functional notation.
- `css` *(bool, `false`)* — preset enabling `rgb_fn`, `hsl_fn`, `names`, `RGB`, `RRGGBB`.
- `css_fn` *(bool, `false`)* — preset enabling `rgb_fn` + `hsl_fn` only.
- `tailwind` *(bool|string, `false`)* — Tailwind class detection. `true` / `"normal"` / `"lsp"` / `"both"`.
- `sass` *(table, `{ enable = false }`)* — Sass `$var` resolution.
- `mode` *(string, `"background"`)* — `"background"` (recolor literal bg), `"foreground"` (recolor literal fg), or `"virtualtext"` (trailing block).
- `virtualtext` *(string, `"■"`)* — the glyph used in `virtualtext` mode.
- `always_update` *(bool, `false`)* — update unfocused buffers.

## Our config
- `user_default_options.css = true` — pulls in `rgb_fn`, `hsl_fn`, `names`, plus hex forms.
- `user_default_options.tailwind = true` — highlight Tailwind class names by their resolved color.
- `user_default_options.mode = "virtualtext"` — keeps source readable (no recoloring of the literal itself), shows a swatch beside it.
- Loads on `BufReadPost`.

## Keymaps
None. Commands inherited from upstream: `:ColorizerToggle`, `:ColorizerAttachToBuffer`, `:ColorizerDetachFromBuffer`, `:ColorizerReloadAllBuffers`.

## Links
- README: https://github.com/NvChad/nvim-colorizer.lua/blob/master/README.md
- Help: `:help colorizer`

## Notes
- `user_default_options` is the legacy flat schema and is documented as frozen — new features land in the structured `options` table. The legacy format is fine for our use case.
- `tailwind = true` requires Tailwind class names in source; the matcher works on bare strings (e.g. `"bg-red-500"`).
- In `virtualtext` mode the swatch is an extmark — it doesn't shift column counts and survives `gJ`/`J` formatting.
