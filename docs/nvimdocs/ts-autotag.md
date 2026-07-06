# ts-autotag
> Auto-close and auto-rename paired HTML/JSX/Vue/Angular tags using treesitter.

**Repo:** https://github.com/windwp/nvim-ts-autotag
**Local spec:** lua/plugins/treesitter.lua:160end
**Tags:** treesitter, html, jsx, tags, editing

## Scope
Closes a tag automatically after typing `>` and renames the matching pair when you edit either side. Driven by treesitter parsers (html, tsx, vue, angular, etc.), so it stays accurate inside nested template literals and component templates.

## Install spec
```lua
{
  "windwp/nvim-ts-autotag",
  event = "InsertEnter",
  opts = {},
}
```

## Common customizations
- `opts.enable_close` *(boolean, default `true`)* — auto-close tags on `>`.
- `opts.enable_rename` *(boolean, default `true`)* — auto-rename the matching tag when one side is edited.
- `opts.enable_close_on_slash` *(boolean, default `false`)* — also close when typing `</`.
- `per_filetype` *(table)* — per-filetype overrides for the three flags above, e.g. `per_filetype = { html = { enable_close = false } }`.
- `aliases` *(table)* — map unsupported filetypes onto a supported config (e.g. `aliases = { ["my-html"] = "html" }`).

## Our config
- `opts = {}` — all defaults. That gives close-on-`>` and rename-on-edit for every supported filetype, no close-on-`/`.
- No `per_filetype` or `aliases` set; relies on the upstream filetype list (html, xml, tsx, jsx, vue, svelte, php, markdown, astro, glimmer, handlebars, htmldjango, eruby, angular templates).

## Keymaps
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| — | — | — | None — operates implicitly on `InsertCharPre`. |

## Links
- README: https://github.com/windwp/nvim-ts-autotag/blob/main/README.md
- Related: [ts-nvim-treesitter](ts-nvim-treesitter.md)

## Notes
- Loaded on `InsertEnter` so the startup cost is paid only the first time you start editing.
- Requires the relevant parsers from [ts-nvim-treesitter](ts-nvim-treesitter.md) — our install list covers html, tsx, typescript, javascript, php, markdown, angular, embedded_template.
- For Angular component template strings, rename works inside backticks because the angular parser injects into `@Component({ template: ... })`.
