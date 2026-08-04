# ui-tiny-inline-diagnostic
> Pretty inline LSP diagnostic display using the `modern` preset; replaces vim.diagnostic's default virtual-text.

**Repo:** https://github.com/rachartier/tiny-inline-diagnostic.nvim
**Local spec:** lua/plugins/ui.lua:183
**Tags:** lsp, diagnostics, ui, virtualtext

## Scope
Renders the current-line diagnostic as an arrow + colored chunk to the right of the code, instead of trailing one-line text. Loads only after `LspAttach` (no cost in non-LSP buffers). Uses the `"modern"` preset for the chunk shape.

It also owns end-of-line virtual text outright: nvim-lightbulb is configured sign-only precisely so the two don't stack on the same line (see [lsp-lightbulb](lsp-lightbulb.md)). Native `vim.diagnostic` `virtual_lines` was evaluated as a replacement and rejected — it inserts real lines and shifts code down.

## Install spec
```lua
{
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "LspAttach",
  priority = 1000,
  config = function()
    require("tiny-inline-diagnostic").setup({
      preset = "modern",
      options = {
        show_source = { enabled = true, if_many = true },
        multilines = { enabled = true, always_show = false },
      },
    })
  end,
}
```

## Common customizations
Passed to `setup()`:

- `preset` *(string, `"modern"`)* — visual style. Options: `"modern"`, `"classic"`, `"minimal"`, `"powerline"`, `"ghost"`, `"simple"`, `"nonerdfont"`, `"amongus"`.
- `signs` *(table)* — glyphs for `left`, `right`, `diag`, `arrow`, `up_arrow`, `vertical`, `vertical_end`. Defaults are preset-derived.
- `hi` *(table)* — highlight links per severity (`error`, `warn`, `info`, `hint`), plus `arrow`, `background`, `mixing_color` (default `"Normal"`).
- `transparent_bg` *(bool, `false`)* — drop the diagnostic background fill.
- `transparent_cursorline` *(bool, `true`)* — transparent cursorline within the diagnostic.
- `disabled_ft` *(list, `{}`)* — filetypes to skip.
- `options.show_source` *(bool, `false`)* — append `[source]` to the message.
- `options.show_code` *(bool, `true`)* — show the diagnostic code (e.g. `E0382`).
- `options.throttle` *(int ms, `20`)* — debounce redraws.
- `options.softwrap` *(int, `30`)* — wrap threshold in columns.
- `options.multilines` *(bool/table, `false`)* — enable multi-line messages.
- `options.show_all_diags_on_cursorline` *(bool, `false`)* — show every diag on the current line, not just the first.
- `options.enable_on_insert` *(bool, `false`)* — display in insert mode.
- `options.overflow.mode` *(string, `"wrap"`)* — `"wrap"`, `"none"`, or `"oneline"` when message exceeds window.
- `options.format` *(fn, nil)* — `function(diag) return string end` for custom formatting.
- `options.virt_texts.priority` *(int, `2048`)* — extmark priority.

## Our config
- `preset = "modern"` — sleeker chunk shape than the previous `"powerline"` (which drew angular
  powerline arrows that fought the flat, separator-less lualine).
- `options.show_source = { enabled = true, if_many = true }` — names the server only when several
  are attached, which is the normal case here: php = phpantom_lsp + laravel_lsp, ts = vtsls +
  typos_lsp + tailwindcss. Without it a message was unattributable.
- `options.multilines = { enabled = true, always_show = false }` — diagnostics on lines other than
  the cursor line stay visible instead of vanishing until you land on them.
- `event = "LspAttach"` — first activation when any LSP client attaches.
- `priority = 1000` — load early relative to other LspAttach handlers, so the plugin's own `vim.diagnostic.config` patch (disabling default virtual_text) runs first.

## Keymaps
None.

## Links
- README: https://github.com/rachartier/tiny-inline-diagnostic.nvim/blob/main/README.md

## Notes
- The plugin internally calls `vim.diagnostic.config({ virtual_text = false })` so you don't have to. If you re-enable `virtual_text` elsewhere, both will render and overlap.
- `priority = 1000` matters because some LSP setups also touch `vim.diagnostic.config` on `LspAttach`; loading this plugin first lets it set the canonical state.
- Severity-conditional rendering (e.g. only show ERROR/WARN) is done via `vim.diagnostic.config({ severity = ... })` upstream — this plugin honors whatever filter `vim.diagnostic` already applies.
