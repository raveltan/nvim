# diagram-image-nvim
> Terminal-native image rendering — the canvas that diagram.nvim and markdown preview draw onto.

**Repo:** https://github.com/3rd/image.nvim
**Local spec:** lua/plugins/diagram.lua:5-28
**Tags:** diagram image kitty magick markdown render

## Scope
Renders raster images directly in a graphics-capable terminal (Kitty graphics protocol or Überzug++). It is the substrate for inline image display in Markdown buffers and the renderer for `3rd/diagram.nvim`. We use it on `markdown` and `norg` filetypes only, with the `magick_cli` processor so we do not need the luarocks `magick` binding.

## Install spec
```lua
{
  "3rd/image.nvim",
  build = false, -- skip luarocks; we use the bundled magick_rock path via CLI
  ft = { "markdown", "norg" },
  opts = {
    backend = "kitty",
    processor = "magick_cli",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = true,
        filetypes = { "markdown", "vimwiki" },
      },
    },
    max_width = 100,
    max_height = 12,
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = true,
    editor_only_render_when_focused = true,
  },
}
```

## Common customizations
- `backend` *(string, default `"kitty"`)* — `"kitty"` for Kitty/Ghostty/WezTerm-with-Kitty-proto, `"ueberzug"` for X11 fallback. Set to match your terminal.
- `processor` *(string, default `"magick_rock"`)* — image decoder. `"magick_rock"` needs the luarocks `magick` Lua binding; `"magick_cli"` shells out to the `magick`/`convert` CLI instead (our choice).
- `integrations.markdown.enabled` *(bool)* — auto-render `![alt](path)` images in markdown buffers.
- `integrations.markdown.clear_in_insert_mode` *(bool)* — hide images while typing.
- `integrations.markdown.only_render_image_at_cursor` *(bool)* — render just the image under cursor; trades visual density for performance.
- `integrations.markdown.download_remote_images` *(bool)* — fetch `http(s)://` image URLs to a cache dir before rendering.
- `integrations.markdown.filetypes` *(string[])* — extra filetypes that share the markdown integration (vimwiki here).
- `integrations.neorg.enabled` *(bool)* — analogous for `norg`. Disabled by default in our config; rely on diagram.nvim's neorg integration instead.
- `integrations.html`, `integrations.css` — opt-in renderers for `<img>` / `background-image:` URLs.
- `max_width`, `max_height` *(int, cells)* — hard caps in terminal cells.
- `max_width_window_percentage`, `max_height_window_percentage` *(int 0-100 | nil)* — soft caps relative to window size; `nil` disables.
- `window_overlap_clear_enabled` *(bool)* — auto-clear images when a float/popup covers them.
- `editor_only_render_when_focused` *(bool)* — pause rendering when Neovim loses terminal focus.
- `kitty_method` *(string, default `"normal"`)* — `"unicode-placeholders"` if your kitty version supports it; mildly faster.
- `tmux_show_only_in_active_window` *(bool)* — tmux-specific gating.

## Our config
- `build = false` — skip luarocks at install. The bundled `magick_rock` git submodule is fine for `magick_cli`.
- `ft = { "markdown", "norg" }` — never load for code buffers; image.nvim's overhead is real.
- `backend = "kitty"`, `processor = "magick_cli"` — Kitty graphics protocol via ImageMagick CLI. Requires `magick` (v7) or `convert` (v6) on `$PATH`.
- `only_render_image_at_cursor = true` — single-image render budget; pairs well with `<leader>dd` in diagram.nvim.
- `download_remote_images = true` — so README links to raw.githubusercontent.com etc. render inline.
- `max_width = 100`, `max_height = 12`, `max_height_window_percentage = 50` — keeps diagrams from eating the whole split.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|

(No direct keymaps. `<leader>dd` is owned by [diagram-nvim](diagram-nvim.md).)

## Links
- README: https://github.com/3rd/image.nvim
- Kitty graphics protocol: https://sw.kovidgoyal.net/kitty/graphics-protocol/
- Related: [diagram-nvim](diagram-nvim.md), [markview](markview.md)

## Notes
- `magick_cli` requires ImageMagick on `$PATH`. macOS: `brew install imagemagick`.
- If images flicker on scroll, raise `editor_only_render_when_focused` and try toggling `window_overlap_clear_enabled`.
- Kitty graphics works inside tmux only with `allow-passthrough on`; without it, fall back to `backend = "ueberzug"` (Linux only).
- SVGs from devdocs are stripped before reaching image.nvim — see [docs-devdocs](docs-devdocs.md) Notes.
