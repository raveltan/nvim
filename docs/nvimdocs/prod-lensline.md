# prod-lensline
> Virtual-line "lens" above functions — author + cyclomatic complexity, no LSP refcount storms.

**Repo:** https://github.com/oribarilan/lensline.nvim
**Local spec:** lua/plugins/productivity.lua:142-169
**Tags:** lens code-lens complexity git-blame virtual-text

## Scope
Renders a single virtual line above each function/method (treesitter-detected) with metadata from configurable providers. Unlike `vim.lsp.codelens`, it does not hammer the LSP for reference/implementation counts — providers are local (git blame, treesitter complexity). Placed *above* the function so it sits between PHPDoc/JSDoc and the declaration.

## Install spec
```lua
{
  "oribarilan/lensline.nvim",
  event = "LspAttach",
  opts = { profiles = { ... }, limits = { ... } },
}
```

## Common customizations
- `profiles` *(list of tables)* — named provider sets. Each profile has `name`, `providers`, optional `style`.
  - `providers[].name` *(string)* — `"last_author"` (git blame of the function line), `"complexity"` (cyclomatic), `"references"` (LSP refcount), `"diagnostics"`, `"function_size"`. Custom providers possible.
  - `providers[].enabled` *(bool)* — toggle the provider.
  - `providers[].min_level` *(string, complexity-only)* — minimum severity to display; one of `"S"`, `"M"`, `"L"`, `"XL"` (small/medium/large/extra-large). `"S"` shows everything.
- `style` *(table)*:
  - `placement` *("above"|"inline", "above")*
  - `prefix` *(string)* — leading glyph.
  - `separator` *(string)* — between provider outputs.
  - `use_nerdfont` *(bool, true)*
  - `render` *("all"|"focused", "all")*
- `limits.exclude` *(table)* — filetypes where lens is suppressed.
- `limits.max_lines` *(number, 1000)* — skip files larger than this.
- `limits.max_lenses` *(number)* — cap rendered lenses per buffer.
- `debounce_ms` *(number, 500)* — recompute delay after edits.

See https://github.com/oribarilan/lensline.nvim#configuration.

## Our config
Single profile `"default"`:
- Providers:
  - `last_author` — git blame author of the function's defining line.
  - `complexity` with `min_level = "S"` — show for every function (smallest threshold).
- Style: `placement="above"`, `prefix="┃ "`, `separator=" • "`, `use_nerdfont=true`.
- Limits:
  - `exclude`: `lazy, mason, TelescopePrompt, neo-tree, trouble, help, qf, snacks_picker_list, snacks_picker_input`.
  - `max_lines = 1000` — disabled in big files.

Loaded on `LspAttach` (lensline itself doesn't *require* LSP for our providers, but this is a convenient trigger that fires for any real source buffer).

## Keymaps
None defined. Plugin commands: `:Lensline toggle|enable|disable|refresh`.

## Links
- README: https://github.com/oribarilan/lensline.nvim
- Related: [ts-nvim-treesitter](ts-nvim-treesitter.md)

## Notes
- `last_author` shells out to `git blame` per function; cached per buffer per edit, so the cost is bounded.
- `complexity` uses treesitter — install the parser for the language you're editing or no lens shows.
- `min_level = "S"` is the most verbose; bump to `"M"` if every tiny helper getting a lens feels noisy.
- The `┃` prefix prints as a thin vertical bar — distinguishes lensline output from diagnostics virtual text.
