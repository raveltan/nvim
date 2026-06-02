# tagmatch.nvim

Treesitter-based tag matching for Neovim. Jump between an element's opening and
closing tag with `%`, and operate on tags with the `i%` / `a%` text objects — across
**every grammar that exposes HTML- or JSX-style element nodes**.

| Keys | Action |
|------|--------|
| `%` (normal/visual) | jump between `<tag>` and `</tag>` |
| `di%` `ci%` `yi%` `vi%` … | inner tag (content between the tags) |
| `da%` `ca%` `ya%` `va%` … | around tag (the whole element incl. tags) |

Works in: **html, xml, Angular** (including inline `template:` strings in `.ts`),
**JSX/TSX** (React, incl. fragments `<>…</>`), **Vue, Svelte, eruby, php, markdown** —
anything whose treesitter tree (native or injected) contains element nodes. Handles
hyphenated custom elements (`<fl-button>`, `<my-widget>`), nesting, and multi-line tags.

## Why not matchit / vim-matchup for this?

`b:match_words` (matchit/matchup) matches poorly here: it skips matches inside string
literals (so Angular inline templates are invisible), can't follow injected trees
(eruby/php/Angular), and its html mode matches the angle brackets `<`…`>` rather than
the open/close **tag pair**. The treesitter tree knows the real structure.

tagmatch only takes over when the cursor is on a tag — otherwise it **falls back** to
vim-matchup (if installed) or the builtin `%`, so ordinary bracket matching is intact.

## Install (lazy.nvim)

```lua
{
  "you/tagmatch.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" }, -- and optionally vim-matchup
  ft = { "html", "xml", "vue", "svelte", "eruby", "php", "markdown",
         "javascript", "javascriptreact", "typescript", "typescriptreact" },
  opts = {},
}
```

Requires the relevant treesitter parsers installed (`html`, `angular`, `tsx`,
`javascript`, `php`, `embedded_template`, …).

## Configuration (defaults)

```lua
require("tagmatch").setup({
  -- Filetypes to attach to. Safe to over-include: the cursor-on-tag check self-gates,
  -- so non-tag positions just fall back.
  filetypes = {
    "html", "xml", "xhtml", "htmlangular", "vue", "svelte", "handlebars",
    "htmldjango", "heex", "eruby", "php", "markdown", "javascript",
    "javascriptreact", "jsx", "typescript", "typescriptreact", "tsx", "astro",
  },
  -- Set any to false to skip it; change the lhs to remap.
  mappings = { jump = "%", inner = "i%", around = "a%" },
  -- Keys fed when NOT on a tag. nil = auto (vim-matchup <Plug> if present, else builtin
  -- `%` for jump / nothing for the text objects). false = no fallback. string = feed it.
  fallback = { jump = nil, inner = nil, around = nil },
})
```

### Remap example

```lua
-- prefer `m` for tag jump, keep matchup's `%`
require("tagmatch").setup({ mappings = { jump = "m", inner = "im", around = "am" } })
```

## Bonus: `dit` / `cit` on custom elements (mini.ai)

`dit`/`cit`/`dat`/`cat` go through mini.ai's `t` text object (if you use mini.ai),
whose default tag-name pattern uses `%w` and so **stops at the hyphen** in
`<fl-button>`. tagmatch doesn't touch `t`; fix it in your mini.ai config:

```lua
require("mini.ai").setup({
  custom_textobjects = {
    -- widen the tag-name class + frontier to allow `-`
    t = { "<([%w%-]-)%f[^<%w%-][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
  },
})
```

## How it works

Two node-type families cover everything:

- **HTML-family** (`html`, `angular`, and injected html in `eruby`/`php`):
  `element` / `start_tag` / `end_tag` / `self_closing_tag`.
- **JSX-family** (`tsx`, `javascript`): `jsx_element` / `jsx_opening_element` /
  `jsx_closing_element` / `jsx_self_closing_element`. Fragments are a `jsx_element`
  whose open/close have no name.

Node types are globally unique, so one matcher with union sets handles both. Nodes are
resolved across all injected trees (`for_each_tree`), so tags inside a `.ts` template
string, an `.erb`, or a `.php` file are found even though the outer tree reports only
text there. Inner selection prefers the element's named content children (clean across
multi-line start tags) and falls back to the byte span between the tags for non-native
content (e.g. eruby `<%= … %>`).
