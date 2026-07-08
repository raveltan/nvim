# editor-mini-ai
> Smarter `a`/`i` text objects with next/last variants, treesitter integration, and richer pair handling.

**Repo:** https://github.com/echasnovski/mini.ai (part of https://github.com/echasnovski/mini.nvim)
**Local spec:** lua/plugins/editor.lua:158
**Tags:** text-objects, mini, motion

## Scope
Replaces and extends Neovim's built-in `a`/`i` text objects so that `vaq`, `cin`, `da)`, etc. work across multi-line constructs, balanced pairs, and language-aware regions. Adds next/last variants (`an{` jumps to the next `{...}`) and integrates with treesitter when available.

## Install spec
```lua
{
  "echasnovski/mini.ai",
  event = "VeryLazy",
  opts = function()
    local ai = require("mini.ai")
    return {
      n_lines = 500, -- default 50 misses tall multi-line elements
      custom_textobjects = {
        -- hyphen-aware `t`: upstream's `(%w-)` tag-name pattern stops at the first
        -- hyphen, so dit/dat fail on custom elements (<fl-button>, <app-foo-bar>).
        t = { "<([%w%-]-)%f[^<%w%-][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
        -- Treesitter-backed f/c/a (definitions) — sole owner of af/if/ac/ic/aa/ia.
        f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
        c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
        a = ai.gen_spec.treesitter({ a = "@parameter.outer", i = "@parameter.inner" }),
      },
    }
  end,
}
```

## Common customizations
- `n_lines` *(number, 50)* — lines around cursor scanned for a text object.
- `search_method` *(string, "cover_or_next")* — `cover`, `cover_or_next`, `cover_or_prev`, `cover_or_nearest`, `next`, `prev`, `nearest`.
- `mappings.around` *(string, "a")* — outer text-object key.
- `mappings.inside` *(string, "i")* — inner text-object key.
- `mappings.around_next` / `inside_next` *(string, "an"/"in")* — next-variant prefixes.
- `mappings.around_last` / `inside_last` *(string, "al"/"il")* — last-variant prefixes.
- `mappings.goto_left` / `goto_right` *(string, "g[" / "g]")* — jump to edges of text object.
- `silent` *(bool, false)* — suppress messages on missing object.
- `custom_textobjects` *(table)* — define new identifiers, e.g. `{ F = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }) }`.

## Our config
`n_lines = 500` (find objects across tall multi-line constructs) and a hyphen-aware `t` tag override so `dit`/`cit`/`dat`/`cat` match hyphenated custom elements. `f`/`c`/`a` are treesitter-backed via `gen_spec.treesitter` (definitions, not mini.ai's default call/argument patterns) — mini.ai is the sole owner of `af`/`if`/`ac`/`ic`/`aa`/`ia`; the equivalent nvim-treesitter-textobjects select maps were removed (they shadowed mini.ai and lost counts, `an`/`al` variants, dot-repeat). All other built-in identifiers at defaults. mini.surround carries the same `t` fix on its side ([editor-mini-surround](editor-mini-surround.md)).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `a{id}` | x / o | around | Outer text object incl. delimiters |
| `i{id}` | x / o | inside | Inner text object excl. delimiters |
| `an{id}` | x / o | around next | Next occurrence (outer) |
| `in{id}` | x / o | inside next | Next occurrence (inner) |
| `al{id}` | x / o | around last | Previous occurrence (outer) |
| `il{id}` | x / o | inside last | Previous occurrence (inner) |
| `g[{id}` | n / x / o | goto_left | Jump to left edge |
| `g]{id}` | n / x / o | goto_right | Jump to right edge |

Built-in identifiers: `(` `)` `[` `]` `{` `}` `<` `>` `"` `'` `` ` `` `t` (tag) `?` (prompt) `q` (any quote) `b` (any bracket). Overridden here: `f` (function def), `c` (class), `a` (parameter) — treesitter definitions via `gen_spec.treesitter`.

## Links
- README: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md
- `:help mini.ai`

## Notes
- The `a` argument object treats commas correctly across nested calls/generics.
- The `gen_spec.treesitter` specs read the `textobjects.scm` queries shipped by `nvim-treesitter-textobjects` ([ts-textobjects](ts-textobjects.md)), which stays installed for queries, motions (`]f` `[f` `]a` `[a`) and swaps.
