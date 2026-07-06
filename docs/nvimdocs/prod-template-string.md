# prod-template-string
> Auto-converts `"..."` / `'...'` to template literals `` `...` `` when you type `${`.

**Repo:** https://github.com/axelvc/template-string.nvim
**Local spec:** lua/plugins/productivity.lua:56
**Tags:** typescript javascript jsx template-literal quality-of-life

## Scope
Watches inserts inside string quotes. The moment you type `${`, it rewrites the enclosing quotes to backticks. Optionally reverses the conversion if you delete the last interpolation. Filetype-gated.

## Install spec
```lua
{
  "axelvc/template-string.nvim",
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = {
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    jsx_brackets = true,
    remove_template_string = true,
  },
}
```

## Common customizations
- `filetypes` *(table, { "typescript", "javascript", "typescriptreact", "javascriptreact", "vue", "svelte", "python" })* — filetypes to activate on.
- `jsx_brackets` *(bool, true)* — when converting a JSX attribute value (e.g. `foo="bar"`), wrap the new template literal in `{}` to keep it valid JSX.
- `remove_template_string` *(bool, false)* — if you delete the last `${...}` from a template literal, convert backticks back to regular quotes.
- `restore_quotes` *(table, { normal = "'", jsx = '"' })* — which quote style to restore to when `remove_template_string` triggers.

See https://github.com/axelvc/template-string.nvim#configuration.

## Our config
- Loads only for TS/TSX/JS/JSX (`ft`).
- `filetypes` mirrors the `ft` list — no Vue/Svelte/Python.
- `jsx_brackets = true` so JSX attrs get `{` `}` wrapping automatically.
- `remove_template_string = true` so deleting interpolations cleans up backticks.

## Keymaps
None — fully automatic on insert.

## Links
- README: https://github.com/axelvc/template-string.nvim
- Related: [prod-typescript-tools](prod-typescript-tools.md)

## Notes
- Triggers on `InsertCharPre`/`TextChangedI` — no perf hit on non-string keystrokes.
- If conversion misfires inside multi-line strings, check that treesitter parser for `typescript`/`tsx` is installed (`:TSInstall typescript tsx`).
