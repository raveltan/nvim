# editor-dial
> Enhanced `<C-a>` / `<C-x>` increment/decrement: booleans, dates, semver, hex, custom word swaps.

**Repo:** https://github.com/monaqa/dial.nvim
**Local spec:** lua/plugins/editor.lua:198
**Tags:** editor, increment, dates, semver, augend

## Scope

`dial.nvim` replaces the built-in `<C-a>`/`<C-x>` with a configurable pipeline of "augends" — match-and-transform rules. The first augend whose pattern hits the cursor word wins. Useful for toggling `true`/`false`, bumping ISO dates, walking a semver, or flipping `&&`/`||` inside conditionals.

## Install spec

```lua
{
  "monaqa/dial.nvim",
  keys = {
    { "<C-a>", function() require("dial.map").manipulate("increment", "normal") end },
    { "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end },
    { "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, mode = "v" },
    { "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, mode = "v" },
  },
  config = function() require("dial.config").augends:register_group({ default = { ... } }) end,
}
```

Lazy-loaded on the four keymaps — no event needed.

## Common customizations

- `augends:register_group({ default = {...} })` *(table)* — ordered augend list for the `default` group. Order is precedence.
- `augend.integer.alias.decimal_int` — base-10 integers (signed).
- `augend.integer.alias.hex` — `0x` prefixed hex.
- `augend.integer.alias.octal` / `binary` — also available.
- `augend.constant.alias.bool` — toggles `true`/`false`.
- `augend.date.alias["%Y-%m-%d"]` — ISO date, walks years/months/days based on cursor segment.
- `augend.date.alias["%Y/%m/%d"]` — slash variant.
- `augend.semver.alias.semver` — major.minor.patch; cursor segment decides which part bumps.
- `augend.constant.new({ elements = {...}, word = true, cyclic = true })` — custom cycling word list. `word = false` allows non-`\k` matches like `&&`/`||`.
- `augend.hexcolor.new({ case = "lower" })` — `#rrggbb` channel walker (not used here).
- Multiple named groups: pass `group_name` arg to `manipulate` to switch contexts (e.g. per-filetype).

## Our config

Single `default` group with these augends, in order:

1. `integer.alias.decimal_int`
2. `integer.alias.hex`
3. `constant.alias.bool` — `true`/`false`
4. `date.alias["%Y-%m-%d"]`
5. `date.alias["%Y/%m/%d"]`
6. `semver.alias.semver`
7. `{ "true", "false" }` (custom — duplicates #3 for unambiguous match on bare word)
8. `{ "True", "False" }` — Python-style booleans
9. `{ "yes", "no" }`
10. `{ "on", "off" }`
11. `{ "let", "const" }` — JS/TS declaration swap
12. `{ "&&", "||" }` with `word = false` — boolean operator flip

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<C-a>` | n | `dial.map.manipulate("increment","normal")` | Increment / cycle next |
| `<C-x>` | n | `dial.map.manipulate("decrement","normal")` | Decrement / cycle prev |
| `<C-a>` | v | `dial.map.manipulate("increment","visual")` | Increment selection |
| `<C-x>` | v | `dial.map.manipulate("decrement","visual")` | Decrement selection |

## Links

- Plugin repo: https://github.com/monaqa/dial.nvim
- Augend reference: https://github.com/monaqa/dial.nvim/blob/master/doc/dial.txt

## Notes

- Visual-mode `g<C-a>` / `g<C-x>` (sequential increments across lines) are not bound; add them if you need numbered-list renumbering.
- Custom `constant.new` entries with `word = false` are required for operator-like augends — without it, `dial` uses `\k` boundaries and won't match `&&`.
- The duplicate `{ "true", "false" }` after `bool` alias is intentional: `bool` alias also matches `TRUE`/`True` variants, so the explicit list gives priority to exact lowercase.
