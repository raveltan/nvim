# editor-tagmatch
> Treesitter tag matching: `%` jump between open/close tags, `i%`/`a%` tag text objects, and tag-pair rename — html, JSX/TSX, Angular (incl. inline templates), Vue, Svelte, eruby, php, ...

**Local module:** lua/tagmatch/init.lua (in-repo, not a plugin — see lua/tagmatch/README.md)
**Setup:** init.lua calls `require("tagmatch").setup()` eagerly (cost: one FileType autocmd + two `<Plug>` maps)
**Tags:** treesitter, tags, text-objects, matchup, html, jsx, angular

## Scope

Treesitter-based tag structure awareness. The tree (native or injected) knows the real element pairs — including hyphenated custom elements (`<fl-button>`), nesting, multi-line tags, and tags inside Angular inline `template:` strings or eruby/php files where regex/matchit approaches fail. Outside a tag, every mapping falls back to vim-matchup (if present) or builtin `%`, so ordinary bracket matching is untouched.

Formerly a `dir=`-style local plugin at `tagmatch.nvim/`; moved into `lua/tagmatch/` so it lives with the rest of the config (the lazy spec `lua/plugins/tagmatch.lua` was deleted).

## Keymaps (buffer-local, on matching filetypes)

| Key | Mode | Action |
|---|---|---|
| `%` | n, x | jump between `<tag>` and `</tag>` |
| `di%` `ci%` `yi%` `vi%` … | x, o | inner tag (content between the tags) |
| `da%` `ca%` `ya%` `va%` … | x, o | around tag (whole element incl. tags) |
| `<leader>cr` on a tag name | n | rename the open/close pair (routed via [config-rename](config-rename.md)) |

Filetypes: html, xml, xhtml, htmlangular, vue, svelte, handlebars, htmldjango, heex, eruby, php, markdown, javascript(react), typescript(react), jsx/tsx, astro. Safe to over-include — the cursor-on-tag check self-gates.

## Rename API

- `require("tagmatch").rename()` — prompt (`vim.ui.input`) and rename the tag pair under the cursor; both name spans update via `nvim_buf_set_text` (bottom-up so ranges stay valid). Self-closing tags get one edit. Returns `false` without prompting when the cursor isn't on tag markup (the name or `<` `>` `/` punctuation) — attributes and content decline so callers can fall through to LSP rename.
- `require("tagmatch").rename_info()` — current tag name (or nil) without prompting; used by config/rename.lua to defer uppercase JSX/Vue components to LSP rename.

## Links

- Full readme: `lua/tagmatch/README.md` (node-type families, fallback design, config)
- Rename routing: [config-rename](config-rename.md)
- Fallback partner: [editor-vim-matchup](editor-vim-matchup.md)
- Related: [ts-autotag](ts-autotag.md) (auto close/rename while typing — different job)

## Notes

- Node resolution walks **all injected trees** (`parser:for_each_tree`), which is why Angular inline templates and eruby/php embedded html work.
- Two node-type families cover everything: html-family (`element`/`start_tag`/`end_tag`/`self_closing_tag`) and jsx-family (`jsx_element`/…). Types are globally unique, so union sets need no per-language dispatch.
- `i%`/`a%` are `<expr>` maps that return either our `<Plug>` handler or matchup's, because operator-pending mode can't take an imperative selection.
