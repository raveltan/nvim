# workflow-silicon
> Render the current selection (or buffer) to a PNG via the silicon CLI.

**Repo:** https://github.com/michaelrommel/nvim-silicon
**Local spec:** lua/plugins/silicon.lua:4
**Tags:** workflow silicon screenshot code-image gruvbox

## Scope
Lazy-loaded on `Silicon`/`SiliconAsync` commands and `<leader>cy`/`<leader>cY`. Wraps the Rust `silicon` binary (`brew install silicon`). Hardcoded gruvbox-dark theme, Hack Nerd Font 18pt, generous padding + drop shadow. Saves to `~/Desktop/silicon-<ISO8601>.png` by default; the `clip()` entry point is also bound so you can paste directly.

## Install spec
```lua
{
  "michaelrommel/nvim-silicon",
  cmd = { "Silicon", "SiliconAsync" },
  opts = {
    theme = "gruvbox-dark",
    font = "Hack Nerd Font=18",
    background = "#1d2021",
    pad_horiz = 60,
    pad_vert = 60,
    shadow_blur_radius = 16,
    shadow_offset_x = 8,
    shadow_offset_y = 8,
    shadow_color = "#100808",
    line_pad = 2,
    line_offset = function(args) return args.line1 end,
    tab_width = 2,
    gobble = true,
    output = function() return "~/Desktop/silicon-" .. os.date("!%Y-%m-%dT%H-%M-%S") .. ".png" end,
    to_clipboard = false,
  },
}
```

## Common customizations
- `theme` *(string, "Dracula")* — any theme listed by `silicon --list-themes`. We use `gruvbox-dark`.
- `font` *(string, "Hack")* — font spec `<family>=<size>`. Multiple families joined with `;` for fallback.
- `background` *(hex, "#aaaaff")* — outer canvas color (visible behind shadow + padding).
- `pad_horiz` / `pad_vert` *(int px, 80/100)* — padding between code edges and image bounds.
- `shadow_blur_radius` *(int, 0)* — set >0 to enable drop shadow.
- `shadow_offset_x` / `shadow_offset_y` *(int px, 0/0)* — shadow displacement.
- `shadow_color` *(hex, "#555555")* — shadow tint.
- `line_pad` *(int px, 2)* — vertical space between lines.
- `line_offset` *(int|fn, 1)* — starting line number. We return `args.line1` so visual selections keep their real line numbers.
- `line_number` *(bool, true)* — toggle line numbers entirely.
- `tab_width` *(int, 4)* — spaces per tab.
- `gobble` *(bool, false)* — strip common leading whitespace from selection.
- `output` *(string|fn|false, nil)* — destination path. We use a timestamped function. `false` skips file write (clipboard only).
- `to_clipboard` *(bool, false)* — copy generated PNG to clipboard. Bound separately via `clip()`.
- `language` *(string, nil)* — force a syntax (silicon usually picks from filetype).

## Our config
Dark gruvbox aesthetic to match the editor colorscheme. Background `#1d2021` is gruvbox-dark hard. Big 60px padding + 16px blurred shadow at 8/8 offset for that "presentation slide" look. Output writes to `~/Desktop/silicon-<UTC ISO timestamp>.png` so files sort chronologically and never collide.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>cy` | n, v | `require("nvim-silicon").clip()` | Code → image (clipboard) |
| `<leader>cY` | n, v | `require("nvim-silicon").file()` | Code → image (save file) |

Visual mode renders the selection; normal mode renders the whole buffer.

## Links
- nvim plugin: https://github.com/michaelrommel/nvim-silicon
- silicon CLI: https://github.com/Aloxaf/silicon

## Notes
- Requires the `silicon` binary on `$PATH` — install with `brew install silicon` (macOS) or `cargo install silicon` (cross-platform).
- Font must be installed system-wide (Hack Nerd Font from nerdfonts.com). Silicon doesn't read Neovim's `guifont`.
- `line_offset = function(args) return args.line1 end` is the load-bearing snippet for visual-mode screenshots — without it, every screenshot would start at line 1.
- `SiliconAsync` does the same job in the background; useful for big buffers where blocking the UI for a second matters.
