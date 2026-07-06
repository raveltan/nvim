# ui-noice
> Replaces Neovim's cmdline, messages, and popupmenu UI with floating windows; routes LSP hover and progress through a nicer renderer.

**Repo:** https://github.com/folke/noice.nvim
**Local spec:** lua/plugins/ui.lua:274 (deps include `MunifTanjim/nui.nvim`)
**Tags:** ui, cmdline, messages, lsp, hover

## Scope
Hijacks `vim.ui_attach` and `vim.notify` to render the cmdline, search count, messages, popup menu, and LSP hover/signature via custom views. We delegate signature help to `blink.cmp`, LSP progress to `fidget.nvim`, and only let noice own hover + cmdline + messages. The cmdline is rendered inline (not as a popup) to dodge the `E11` error inside the command-line window (`q:` / `q/`).

## Install spec
```lua
{
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    cmdline = { view = "cmdline" },
    lsp = {
      hover     = { enabled = true },
      signature = { enabled = false },
      message   = { enabled = true },
      progress  = { enabled = false },
      override  = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    views = {
      hover = {
        size = { max_height = 40, max_width = 180 },
        border = { style = "rounded", padding = { 0, 1 } },
      },
    },
    presets = { long_message_to_split = true },
  },
}
```

## Common customizations
- `cmdline.view` *(string, "cmdline_popup")* — `"cmdline"` is the inline (bottom) renderer; `"cmdline_popup"` is the centered float. We use inline to avoid `E11` in command-line windows.
- `cmdline.format` *(table)* — per-prefix icons/labels (search, filter, lua, help).
- `messages.view` *(string, "notify")* — where transient messages go; `mini` or `cmdline_output` are alternatives.
- `messages.view_search` *(string|false, "virtualtext")* — display of `[1/12]` search count.
- `popupmenu.enabled` *(bool, true)* — replace wildmenu/popupmenu.
- `popupmenu.backend` *(string, "nui")* — `"nui"` or `"cmp"`.
- `lsp.hover.enabled` *(bool, true)* — own `vim.lsp.buf.hover`.
- `lsp.signature.enabled` *(bool, true)* — own signature help. Disabled for us (blink.cmp).
- `lsp.progress.enabled` *(bool, true)* — own `$/progress`. Disabled for us (fidget).
- `lsp.override` *(table)* — replace the listed `vim.lsp.util.*` functions so other plugins (cmp) render markdown via noice.
- `views.<name>` *(table)* — override built-in view geometry/border. We bump hover to `40×180` so long TS signatures don't tail-truncate to `@@@`.
- `presets.bottom_search` *(bool)* — push `/` to a bottom popup.
- `presets.long_message_to_split` *(bool)* — route messages that exceed a screen to a horizontal split. We enable it so `:messages`-style spam doesn't blow up the floating notify.
- `presets.command_palette` *(bool)* — VSCode-style centered cmdline+popupmenu.
- `presets.lsp_doc_border` *(bool)* — add a border to hover/signature.
- `routes` *(table[])* — message-filter rules (`filter` + `view`/`opts.skip`).

WebFetch https://raw.githubusercontent.com/folke/noice.nvim/HEAD/README.md for the full schema.

## Our config
- `cmdline.view = "cmdline"` — inline, not popup. Avoids `E11: Invalid in command-line window` inside `q:` / `q/`.
- `lsp.signature.enabled = false` — `blink.cmp` provides signature help.
- `lsp.progress.enabled = false` — `fidget.nvim` owns the progress UI.
- `lsp.override` — three keys flipped to `true` so cmp's docs popup and any plugin calling `vim.lsp.util.stylize_markdown` use noice's markdown renderer.
- `views.hover` — `max_height = 40`, `max_width = 180`, rounded border with `padding = {0, 1}`. The upstream default (`max_height = 20`, no border) truncates long TypeScript type signatures and shows `@@@` at the tail; the override fixes that.
- `presets.long_message_to_split = true` — overflow messages go to a split, not a giant float.

## Keymaps
None defined here. Commands: `:Noice` (history), `:Noice last`, `:Noice dismiss`, `:Noice errors`, `:Noice telescope`.

## Links
- README: https://github.com/folke/noice.nvim/blob/main/README.md
- Default opts: https://github.com/folke/noice.nvim/blob/main/lua/noice/config.lua
- Recipes: https://github.com/folke/noice.nvim/wiki/Configuration-Recipes
- nui.nvim: https://github.com/MunifTanjim/nui.nvim

## Notes
- `nui.nvim` is the rendering layer; do not remove it from dependencies.
- Without `lsp.override`, cmp's documentation popup falls back to vanilla markdown and looks inconsistent vs. hover.
- If hover floats still truncate, raise `views.hover.size.max_height` further or set `border = { style = "single" }` if rounded glyphs render with gaps in your font.
- `presets.long_message_to_split` interacts with `messages.view = "notify"`: short messages still go to notify, only long ones split.
