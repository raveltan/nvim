# ui-hlargs
> Highlights function argument occurrences in a distinct color via Treesitter for fast visual lookup.

**Repo:** https://github.com/m-demare/hlargs.nvim
**Local spec:** lua/plugins/ui.lua:231-245
**Tags:** ui, treesitter, highlight, semantic

## Scope
Walks Treesitter parse trees to find function/method parameters and highlights every usage of each parameter inside the function body with the `Hlargs` highlight group. Makes long function bodies easier to read at a glance because arguments stand out from locals. We disable it on very large buffers to avoid the parse/highlight cost.

## Install spec
```lua
{
  "m-demare/hlargs.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("hlargs").setup()
    vim.api.nvim_create_autocmd("BufReadPost", {
      callback = function(args)
        if vim.api.nvim_buf_line_count(args.buf) > 1500 then
          require("hlargs").disable_buf(args.buf)
        end
      end,
    })
  end,
}
```

## Common customizations
- `color` *(string, "#ef9062")* — the foreground color used for the `Hlargs` group when no theme defines it.
- `highlight` *(table)* — full `nvim_set_hl` opts (fg, bg, bold, italic) for `Hlargs`.
- `excluded_filetypes` *(string[], {})* — disable per filetype (e.g. `{"TelescopePrompt"}`).
- `disable` *(fun(lang, bufnr) → bool)* — custom predicate, e.g. skip large buffers or generated files.
- `paint_arg_declarations` *(bool, true)* — also color the parameter at its declaration site.
- `paint_arg_usages` *(bool, true)* — color the occurrences inside the body.
- `paint_catch_blocks` *(table)* — color exception identifiers in `catch (e)` blocks.
- `extras.named_parameters` *(bool, false)* — paint named call-site args (e.g. Python `foo(x=1)`).
- `hl_priority` *(int, 10000)* — extmark priority vs. other highlight providers like semantic tokens.
- `excluded_argnames.declarations.python` *(string[])* — names to ignore per language (`self`, `cls`).
- `performance.parse_delay` *(int, 1)* — ms debounce after edits.
- `performance.slow_parse_delay` *(int, 50)* — debounce for files over `max_iterations`.
- `performance.max_iterations` *(int, 400)* — node-walk cap before falling back to slow path.

WebFetch https://raw.githubusercontent.com/m-demare/hlargs.nvim/HEAD/README.md if defaults change.

## Our config
- Bare `setup()` — accept upstream defaults (which include reasonable per-language exclusions).
- `BufReadPost` autocmd calls `require("hlargs").disable_buf(bufnr)` when the buffer has > 1500 lines. Large files (generated SDKs, vendored code) re-parse on every edit and slow down typing; disabling per-buffer keeps the global setup intact.

## Keymaps
None bound. Commands: `:HlargsEnable`, `:HlargsDisable`, `:HlargsToggle`, `:HlargsEnableBuf`, `:HlargsDisableBuf`.

## Links
- README: https://github.com/m-demare/hlargs.nvim/blob/main/README.md
- Default opts: https://github.com/m-demare/hlargs.nvim/blob/main/lua/hlargs/config.lua
- Supported languages: see README "Supported languages" section.

## Notes
- Hooks `Hlargs` highlight; most colorschemes don't define it, so set it explicitly in a `ColorScheme` autocmd if the default `#ef9062` clashes.
- Requires the relevant Treesitter parser to be installed for each language — silently no-ops otherwise.
- The 1500-line threshold is a heuristic; lower it (e.g. 800) on slower machines or when editing minified-but-formatted JS.
- For LSP semantic-tokens colorschemes, hlargs may double-paint parameters. Drop `hl_priority` below the semantic-token priority (~125) if you prefer LSP colors.
