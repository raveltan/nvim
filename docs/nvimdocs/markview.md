# markview
> Inline markdown rendering — headings, code blocks, tables, LaTeX, links — without leaving the buffer.

**Repo:** https://github.com/OXY2DEV/markview.nvim
**Local spec:** lua/plugins/editor.lua:94-107
**Tags:** editor markdown render preview latex codecompanion avante

## Scope
Decorates Markdown buffers with concealed/virt-text rendering of headings (icons, underline), code blocks (language label + background), lists, tables, links, callouts, and LaTeX. We enable it for `markdown` plus the two AI chat buffers (`codecompanion`, `Avante`) so AI replies look like rendered Markdown instead of raw text.

## Install spec
```lua
{
  "OXY2DEV/markview.nvim",
  ft = { "markdown", "codecompanion", "Avante" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "echasnovski/mini.icons",
  },
  keys = {
    { "<leader>uM", "<cmd>Markview Toggle<cr>",
      desc = "Toggle markdown render",
      ft = { "markdown", "codecompanion", "Avante" } },
  },
  opts = {
    preview = {
      filetypes = { "markdown", "codecompanion", "Avante" },
      ignore_buftypes = {},
    },
  },
}
```

## Common customizations
- `preview.filetypes` *(string[], default `{"markdown","quarto","rmd","typst"}`)* — buffers eligible for rendering.
- `preview.ignore_buftypes` *(string[], default `{"nofile"}`)* — buftypes excluded; we override with `{}` so floating chat buffers (which are `nofile`) still render.
- `preview.modes` *(string[], default `{"n","no","c"}`)* — modes in which the preview is active. Set to `{"n"}` to disable in command-line mode, or add `"i"` to keep rendering during insert.
- `preview.hybrid_modes` *(string[])* — modes where the line under the cursor is shown as raw markdown. Common pick: `{"i","r"}`.
- `markdown.headings`, `markdown.code_blocks`, `markdown.tables`, `markdown.list_items`, `latex`, `html`, `typst` — per-element renderer tables. Each accepts `enable = false` to skip that node, plus its own style options (see `:help markview.nvim`).
- `:Markview Toggle` / `enable` / `disable` / `hybridToggle` / `splitToggle` — runtime commands.

## Our config
Minimal: we only set `preview.filetypes` and clear `ignore_buftypes`. Everything else (heading icons, code-block styling, link rendering) uses the upstream defaults.

The `Avante` and `codecompanion` filetypes are not in the upstream default list, so adding them is the load-bearing customisation — without it, AI responses render as raw `## headings` and triple-backticks.

`ignore_buftypes = {}` is required because both AI plugins host their chat in a `nofile` buffer; the default ignore list would skip them.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>uM` | n | `:Markview Toggle` | Toggle render in current buffer |

Buffer-local; only bound when the filetype is one of `markdown`, `codecompanion`, `Avante`.

## Links
- README: https://github.com/OXY2DEV/markview.nvim
- Help: `:help markview.nvim`
- Related: [docs-nvimdocs](docs-nvimdocs.md) — these docs are designed to read well under markview.

## Notes
- Requires `nvim-treesitter` with the `markdown` and `markdown_inline` parsers installed; otherwise heading detection silently fails.
- `mini.icons` (not `nvim-web-devicons`) is our icon source; markview auto-detects either.
- If a `codecompanion` buffer does not render, check that the filetype actually matches — some versions of CodeCompanion use `codecompanion` (lowercase) while Avante uses `Avante` (capitalised). We list both.
- Toggling off does *not* unload the plugin; it disables decoration for the current buffer only.
