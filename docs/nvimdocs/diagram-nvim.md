# diagram-nvim

> ⚠️ **REMOVED** — plugin is no longer in this config (inline diagram rendering dropped). Doc kept for history.
> Render mermaid / plantuml / d2 / gnuplot code blocks inline in markdown and neorg.

**Repo:** https://github.com/3rd/diagram.nvim
**Local spec:** lua/plugins/diagram.lua:29-57
**Tags:** diagram mermaid plantuml d2 gnuplot markdown neorg render

## Scope
Watches code blocks tagged `mermaid`, `plantuml`, `d2`, `gnuplot` inside markdown / neorg buffers, shells out to the appropriate CLI renderer, and feeds the resulting PNG to `image.nvim` for inline display. We register both the markdown and neorg integrations, set per-renderer themes, and bind `<leader>dd` to open the current diagram in a dedicated tab.

## Install spec
```lua
{
  "3rd/diagram.nvim",
  dependencies = { "3rd/image.nvim" },
  ft = { "markdown", "norg" },
  opts = function()
    return {
      integrations = {
        require("diagram.integrations.markdown"),
        require("diagram.integrations.neorg"),
      },
      renderer_options = {
        mermaid  = { theme = "dark", scale = 2 },
        plantuml = { charset = "utf-8" },
        d2       = { theme_id = 200 },
        gnuplot  = { theme = "dark", size = "800,600" },
      },
    }
  end,
  keys = {
    { "<leader>dd",
      function() require("diagram").show_diagram_hover() end,
      mode = "n", ft = { "markdown", "norg" },
      desc = "Diagram: show at cursor in new tab" },
  },
}
```

## Common customizations
- `integrations` *(table[])* — list of integration modules. Built-ins: `diagram.integrations.markdown`, `diagram.integrations.neorg`. Each scans its buffer type for fenced blocks.
- `renderer_options.mermaid` — passed to `mmdc`. Notable fields: `theme` (`"default"` | `"dark"` | `"forest"` | `"neutral"`), `scale` (int), `background_color`.
- `renderer_options.plantuml` — passed to `plantuml`. `charset` is the main knob; the renderer also accepts `format` (`"png"` default, `"svg"`).
- `renderer_options.d2` — passed to `d2`. `theme_id` (int — see `d2 themes`), `layout` (`"dagre"` | `"elk"`), `sketch` (bool).
- `renderer_options.gnuplot` — `theme` (`"dark"`|`"light"`), `size` (`"WxH"` string), `font`.
- `events` *(table)* — control when re-render happens; defaults are `render_buffer` on save + `clear_buffer` on close. Usually fine.
- `cache_dir` *(string)* — where PNG output is cached. Default under `stdpath("cache")/diagram-cache`.
- `require("diagram").show_diagram_hover()` — opens the diagram at cursor in a new tab (large preview).
- `require("diagram").get_cache_dir()` — useful for cleanup scripts.

## Our config
- Both `markdown` and `neorg` integrations are registered; the `ft` gate keeps the plugin from loading for code files.
- **mermaid:** `theme = "dark"`, `scale = 2` — doubles the bitmap so it stays crisp at 100-cell width.
- **plantuml:** `charset = "utf-8"` so non-ASCII labels render.
- **d2:** `theme_id = 200` — "Dark Mauve" from the d2 catalog.
- **gnuplot:** `theme = "dark"`, `size = "800,600"` — matches our 16:12-ish image cap.
- `<leader>dd` calls `show_diagram_hover()` for a full-tab preview when the inline render is too small.

## External binaries required
| Renderer | CLI | Install (macOS) |
|---|---|---|
| mermaid | `mmdc` | `npm i -g @mermaid-js/mermaid-cli` |
| plantuml | `plantuml` | `brew install plantuml` |
| d2 | `d2` | `brew install d2` |
| gnuplot | `gnuplot` | `brew install gnuplot` |

A missing binary makes only that renderer silently skip; other diagrams still work.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>dd` | n | `require("diagram").show_diagram_hover()` | Open diagram under cursor in new tab |

`ft`-gated to `markdown` and `norg`.

## Links
- README: https://github.com/3rd/diagram.nvim
- mermaid: https://mermaid.js.org/
- d2 themes: https://d2lang.com/tour/themes
- Related: [diagram-image-nvim](diagram-image-nvim.md), [markview](markview.md)

## Notes
- Render is triggered on `BufWritePost`; an unsaved diagram does not preview.
- The cache key includes the source text, so editing a block invalidates only that one.
- Conflicts with other `<leader>d…` DAP bindings are scoped away by `ft`; in code buffers `<leader>dd` falls through to the DAP namespace.
- If `image.nvim` is not ready (e.g. terminal without Kitty graphics), rendering is a no-op rather than an error.
