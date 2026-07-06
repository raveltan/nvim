# editor-mini-surround
> Add, delete, replace, find, and highlight surrounding pairs with the `gs` prefix.

**Repo:** https://github.com/echasnovski/mini.surround (part of https://github.com/echasnovski/mini.nvim)
**Local spec:** lua/plugins/editor.lua:81
**Tags:** text-objects, surround, mini

## Scope
Provides operators to manipulate pairs of brackets, quotes, tags, and custom surroundings. We remap from the default `sa/sd/sr/...` to a `gs*` prefix so the single-letter `s` stays free for flash.nvim. Pairs with vim-repeat for `.` repeat.

## Install spec
```lua
{
  "echasnovski/mini.surround",
  event = "VeryLazy",
  opts = {
    n_lines = 500, -- default 20 is too small for tall HTML elements
    mappings = {
      add = "gsa",
      delete = "gsd",
      find = "gsf",
      find_left = "gsF",
      highlight = "gsh",
      replace = "gsr",
      update_n_lines = "gsn",
    },
    custom_surroundings = {
      -- hyphen-aware `t` input: upstream's tag-name pattern stops at the first
      -- hyphen, breaking gsdt/gsrt on custom elements (<fl-button>). Only `input`
      -- is overridden; the default add/replace prompt is untouched.
      t = {
        input = { "<([%w%-]-)%f[^<%w%-][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
      },
    },
  },
}
```

## Common customizations
- `mappings.add` *(string, "sa")* — operator to wrap motion/selection with a pair.
- `mappings.delete` *(string, "sd")* — delete surrounding pair.
- `mappings.find` *(string, "sf")* — jump to next surrounding pair right.
- `mappings.find_left` *(string, "sF")* — jump to prev surrounding pair left.
- `mappings.highlight` *(string, "sh")* — briefly highlight surrounding pair.
- `mappings.replace` *(string, "sr")* — replace surrounding pair.
- `mappings.update_n_lines` *(string, "sn")* — change the search line span.
- `mappings.suffix_last`, `mappings.suffix_next` *(string, "l"/"n")* — direction suffixes.
- `n_lines` *(number, 20)* — lines around cursor scanned for a pair.
- `respect_selection_type` *(bool, false)* — wrap visual block selections per row.
- `silent` *(bool, false)* — suppress prompt messages.
- `custom_surroundings` *(table)* — define your own identifiers (e.g. `function call`).
- `search_method` *(string, "cover")* — `cover`, `cover_or_next`, `cover_or_prev`, `cover_or_nearest`, `next`, `prev`, `nearest`.

## Our config
All seven default mappings reprefixed under `gs*`. Which-key registers the `gs` group label (`<leader>` table in editor.lua:293 sets `{ "gs", group = "surround" }`). `n_lines = 500` so multi-line tags are found from anywhere inside them, and the `t` surrounding's input pattern is widened to match hyphenated custom elements (same fix as mini.ai's `t`, see [editor-mini-ai](editor-mini-ai.md)).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `gsa` | n / x | add | Wrap motion/selection with a pair (e.g. `gsaiw)` → wrap word in parens) |
| `gsd` | n | delete | Delete surrounding pair (e.g. `gsd"` → drop quotes) |
| `gsr` | n | replace | Replace surrounding pair (e.g. `gsr"'` → swap `"` for `'`) |
| `gsf` | n | find | Jump right to nearest surrounding char |
| `gsF` | n | find_left | Jump left to nearest surrounding char |
| `gsh` | n | highlight | Briefly flash the surrounding pair |
| `gsn` | n | update_n_lines | Prompt for new `n_lines` search span |

## Links
- README: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-surround.md
- `:help mini.surround`

## Notes
- Built-in identifiers: `(`, `[`, `{`, `<`, `"`, `'`, `` ` ``, `t` (tag), `f` (function call), `?` (interactive).
- vim-repeat (loaded in editor.lua:402) makes `.` repeat `gsd"`, `gsr"'`, etc.
- **Unwrap a tag pair, keep content:** `gsdt` from anywhere inside the element (even multi-line). `2gsdt` targets the second-nearest (outer) tag when nested.
- **`gsr` takes TWO identifiers** (target, then replacement): to rename a tag it's `gsrtt` — the second `t` opens the full "Tag name" prompt. `gsrt<char>` would replace the tag with that literal char.
- For a treesitter-based tag-pair rename bound to `<leader>cr`, see [config-rename](config-rename.md) / [editor-tagmatch](editor-tagmatch.md).
