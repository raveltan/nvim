# editor-textobjects-cheatsheet
> One-page guide to every text object, motion, surround op, and node-select binding active in this config.

**Local spec:** synthesizes [editor-mini-ai](editor-mini-ai.md), [ts-textobjects](ts-textobjects.md), [editor-mini-surround](editor-mini-surround.md), [editor-tagmatch](editor-tagmatch.md), [editor-vim-matchup](editor-vim-matchup.md), [editor-flash](editor-flash.md)
**Tags:** textobjects, motions, surround, treesitter, cheatsheet

## Mental model

Vim composes as `[count] <operator> <textobject>`. Operators: `d` delete, `c` change, `y` yank, `v` visual select, `=` re-indent, `gu`/`gU` lower/upper, `gq` format, `gc` comment. Text objects come in two flavours:
- `i{id}` — **inside**: payload only, no delimiters/whitespace.
- `a{id}` — **around**: payload + delimiters/trailing whitespace.

Example chains:
- `dap` delete a paragraph, `cif` change inside function, `ya"` yank around quotes, `=ic` re-indent class body, `gcip` comment a paragraph.

mini.ai layers two more prefixes onto every id:
- `in{id}` / `an{id}` — **next** occurrence (jump forward then operate).
- `il{id}` / `al{id}` — **last** occurrence (jump back then operate).

Example: `cin)` change inside the next `(...)`, `dal{` delete around the previous `{...}` block.

## Identifiers (what `{id}` can be)

### Built-in Vim
| id | Inside (`i`) | Around (`a`) |
|---|---|---|
| `w` | word | word + trailing ws |
| `W` | WORD (whitespace-delim) | WORD + trailing ws |
| `s` | sentence | sentence + trailing ws |
| `p` | paragraph | paragraph + blank line |
| `"` `'` `` ` `` | quoted string | quoted string + quotes |
| `(` `)` `b` | inside parens | parens included |
| `[` `]` | inside brackets | brackets included |
| `{` `}` `B` | inside braces | braces included |
| `<` `>` | inside angles | angles included |
| `t` | inside HTML/XML tag | tag included |

### mini.ai adds / replaces
| id | Inside | Around | Source |
|---|---|---|---|
| `f` | call args | full `name(...)` call | mini.ai |
| `a` | one argument | arg + comma | mini.ai (treesitter-aware) |
| `q` | inside any quote | any quote pair | mini.ai |
| `b` | inside any bracket | any bracket pair | mini.ai |
| `?` | prompted left/right delim | with prompted delim | mini.ai interactive |
| `t` | inside tag (multi-line) | full tag block | mini.ai (better than native; hyphen-aware — matches `<fl-button>`) |

### Treesitter text objects (this config's keymaps)
Bound directly, not through mini.ai's `{id}` slot:

| Key | Mode | Region |
|---|---|---|
| `if` / `af` | x,o | function body / full function |
| `ic` / `ac` | x,o | class body / full class |
| `ia` / `aa` | x,o | one parameter (ts) / param + comma (ts) |

> Source: `lua/plugins/treesitter.lua:72-77`. `lookahead = true` — works even when cursor sits *before* the function.

### tagmatch + vim-matchup
| id | Inside | Around |
|---|---|---|
| `%` | inside matched pair (tags via tagmatch treesitter; `if/end`, `do/end` via matchup) | pair included |

On a tag, `i%`/`a%` are treesitter-resolved by the in-repo [editor-tagmatch](editor-tagmatch.md) module (handles hyphenated custom elements, JSX, Angular inline templates, injected html in eruby/php); off-tag they fall back to vim-matchup. Example: in Ruby, `da%` deletes the whole `def ... end`; `ci%` clears the body; in html, `di%` clears an element's content.

## Motions (jump without operator)

| Key | Mode | Target | Source |
|---|---|---|---|
| `]f` / `[f` | n,x,o | next/prev function start | ts-textobjects |
| `]a` / `[a` | n,x,o | next/prev parameter start | ts-textobjects |
| `%` | n,x | open ↔ close tag toggle (on a tag) | tagmatch |
| `]%` / `[%` | n,x,o | end/start of containing pair | vim-matchup |
| `g%` | n,x,o | other side of pair (back) | vim-matchup |
| `z%` | n,x,o | inside next pair | vim-matchup |
| `g[f` / `g]f` | n,x,o | left/right edge of function (mini.ai) | mini.ai goto |
| `g[a` / `g]a` | n,x,o | left/right edge of argument | mini.ai goto |
| `s` | n,x,o | flash-jump to any label | flash.nvim |
| `S` | n,x,o | flash treesitter node select | flash.nvim |
| `r` | o | remote-flash operator | flash.nvim |
| `R` | o,x | treesitter-aware search | flash.nvim |

mini.ai's `g[{id}` / `g]{id}` works with **every** id, not just the ones in the table.

## Surround ops (`gs*` prefix)

| Key | Mode | Action | Example |
|---|---|---|---|
| `gsa` | n,x | add | `gsaiw)` wrap word in parens; `gsa$"` wrap to EOL in quotes |
| `gsd` | n | delete | `gsd"` drop surrounding quotes; `gsdt` unwrap tag pair keep content (`2gsdt` outer) |
| `gsr` | n | replace | `gsr"'` swap `"` for `'`; `gsrtt` rename tag (prompts); `gsr(t` parens → HTML tag |
| `gsf` / `gsF` | n | find right/left | jump to next/prev surround char |
| `gsh` | n | highlight | brief flash of the pair |
| `gsn` | n | update n_lines | change scan range (configured to 500) |

`.` (vim-repeat) repeats the last surround op.

Surround identifiers mirror text-object identifiers: `(`, `{`, `[`, `<`, `"`, `'`, `` ` ``, `t` (tag, prompts for name), `f` (function call, prompts for name), `?` (interactive: prompts for both left+right).

## Swap

| Key | Mode | Action |
|---|---|---|
| `<leader>csa` | n | swap current parameter with next |
| `<leader>csA` | n | swap current parameter with previous |

Useful for reordering function args, list elements, hash entries. Reuses ts-textobjects' `@parameter.inner` query.

## Incremental node selection (custom)

| Key | Mode | Action |
|---|---|---|
| `<CR>` | n | start: select current treesitter node |
| `<CR>` | x | expand: grow to parent node |
| `<BS>` | x | shrink: drop to child at cursor |

> Source: `lua/plugins/treesitter.lua:89-125`. Drives `'<` / `'>` marks directly; pairs well with `gv` to restore last selection.

## Common idioms (recipes)

| Goal | Keys |
|---|---|
| Replace word under cursor with yank | `viwp` then `==` |
| Yank function call args | `yif` |
| Delete current function | `daf` |
| Comment paragraph | `gcip` |
| Wrap visual selection in backticks | `<select>` then `gsa` `` ` `` |
| Change inside next `{...}` block | `cin{` |
| Delete previous argument | `dala` |
| Re-indent the enclosing class | `=ac` |
| Jump to end of current `if/end` block | `]%` |
| Select whole HTML tag (incl. attrs) | `vat` or `va%` |
| Unwrap a multi-line `<div>` (keep content) | `gsdt` from anywhere inside |
| Rename a tag pair | `<leader>cr` on the tag name, or `gsrtt` |
| Swap two function args | `<leader>csa` |
| Select expanding by AST | `<CR>` then `<CR><CR>...`, shrink with `<BS>` |
| Operate on a far-away `()` without moving | `dr` then flash label → operates remotely |

## Search method (mini.ai + mini.surround)

Both default to `cover_or_next` — if cursor is on/inside a target, use it; else search forward. To change:

```lua
require("mini.ai").setup({ search_method = "cover_or_nearest" })
require("mini.surround").setup({ search_method = "cover_or_nearest" })
```

`cover_or_nearest` is handy when you frequently sit *between* two pairs.

## Suggested extra plugins

Genuinely additive (don't duplicate what mini.ai + ts-textobjects already give):

### 1. nvim-various-textobjs — high-leverage add
- Repo: https://github.com/chrisgrieser/nvim-various-textobjs
- Adds: `iS`/`aS` (subword), `iv`/`av` (value: after `=`/`:`), `ik`/`ak` (key), `iU`/`aU` (URL), `ii`/`ai` (indentation block — great for Python/YAML), `iC`/`aC` (chain call like `a.b().c`), `iD`/`aD` (number incl. decimals/negatives), `gG` (entire buffer), `iR`/`aR` (regex pattern body), `i,`/`a,` (CSV column).
- Why: complements mini.ai with **semantic** targets. `civ` to change a config value is faster than `ci"` + reaching for the right pair.
- Sample install:
  ```lua
  {
    "chrisgrieser/nvim-various-textobjs",
    event = "VeryLazy",
    opts = { keymaps = { useDefaults = true } },
  }
  ```
- Watch for collisions: `aS`/`iS` (subword) doesn't clash. `ai`/`ii` overlaps with mini.ai's `i` for `[`. If conflict, set `useDefaults = false` and bind only what you want.

### 2. nvim-treehopper — flash-style node picker (alternative to `<CR>` incremental)
- Repo: https://github.com/mfussenegger/nvim-treehopper
- Bind `m` in operator/visual to label every enclosing node — pick one, operate. `dm`, `cm`, `ym`.
- Overlaps with `S` (flash treesitter) but treehopper picks from cursor's **ancestor chain**, not all visible nodes. Often closer to what you want.

### 3. wildfire.nvim — one-key expanding select
- Repo: https://github.com/SirVer/wildfire.vim (vim) or treesitter port
- Press a single key repeatedly to expand selection by AST. The `<CR>`/`<BS>` block already does this, so **skip** unless you prefer one-key over toggling modes.

### 4. mini.operators
- Repo: https://github.com/echasnovski/mini.operators
- Adds operators (not text objects) but pairs naturally: `g=` evaluate, `gx` exchange (swap two regions), `gm` multiply (duplicate), `gr` replace with register, `gs` sort. **`gs` collides** with mini.surround — would need remap.

### 5. treesj — split/join blocks
- Repo: https://github.com/Wansmer/treesj
- `<leader>j` toggles `{a, b, c}` ↔ multi-line. Not a text object but the same workflow neighbourhood.

**Recommendation:** add **nvim-various-textobjs** first — biggest day-to-day win. Add **treehopper** if `<CR>` incremental feels awkward in dense files. Skip the rest unless you hit a specific friction.

## Footguns

- `<CR>` in normal mode is rebound to "start incremental select". Inside quickfix/help it can interfere — `q` closes those buffers (autocmd) so usually fine.
- `s` (flash) overrides the native "substitute char". Use `cl` instead.
- `S` (flash treesitter) overrides "substitute line". Use `cc` instead.
- `r` in operator mode (after `d`/`c`/`y`) is flash remote, not "replace char" (which is normal-mode only — still works).
- mini.surround's default `s*` was remapped to `gs*` to free `s` for flash. Upstream tutorials referencing `sa`/`sd` need translation.
- vim-matchup's `g%` collides with nothing important; but if you've memorized `g%` from elsewhere as "case toggle", that's `g~` here.
- ts-textobjects `aa`/`ia` (parameter) overlaps with mini.ai's `aa`/`ia`. The explicit per-key `map()` in `treesitter.lua` wins because it's registered after mini.ai loads. The ts version is slightly smarter for multi-line args.

## Links

- mini.ai docs: [editor-mini-ai](editor-mini-ai.md)
- ts-textobjects: [ts-textobjects](ts-textobjects.md)
- mini.surround: [editor-mini-surround](editor-mini-surround.md)
- tagmatch (tag `%` + `i%`/`a%` + rename): [editor-tagmatch](editor-tagmatch.md)
- vim-matchup: [editor-vim-matchup](editor-vim-matchup.md)
- flash: [editor-flash](editor-flash.md)
- Master keybind cheatsheet: `docs/keybinds.md` (one level up)
