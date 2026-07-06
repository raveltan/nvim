# editor-ts-comments
> Set `commentstring` based on treesitter context — fixes JSX/Vue/Svelte/Astro nested commenting.

**Repo:** https://github.com/folke/ts-comments.nvim
**Local spec:** lua/plugins/editor.lua:228
**Tags:** comments, treesitter, jsx, vue, commentstring, editor

## Scope

`ts-comments.nvim` patches Neovim's builtin commenting (`gcc`, `gc{motion}`) so that the `commentstring` reflects the treesitter node under the cursor rather than the buffer's filetype default. Inside JSX it picks `{/* ... */}`, inside the surrounding TS it picks `// ...`. Same idea for Vue templates, Svelte, Astro, Markdown code-blocks, embedded SQL, etc.

## Install spec

```lua
{
  "folke/ts-comments.nvim",
  event = "VeryLazy",
  opts = {},
}
```

Neovim 0.10+ ships the comment plugin built-in, so this just registers the hook. Lazy on `VeryLazy` keeps startup fast.

## Common customizations

- `enable` *(bool, true)* — master switch.
- `lang` *(table<string,string|table<string,string>>)* — per-language commentstring map. Keys are treesitter language names. Values are either a single string (use everywhere in that lang) or a table keyed by parent node type for nesting. Defaults already cover `typescriptreact`/`tsx`, `javascriptreact`/`jsx`, `vue`, `svelte`, `astro`, `markdown`, `nu`, `nim`, `glimmer`, `handlebars`, `html`, `php`, plus block-comment forms.
- `lang.<lang>` *(string|table)* — replace or extend the default for one language, e.g. `lang.typescriptreact = { __default = "// %s", call_expression = "// %s", jsx_element = "{/* %s */}", jsx_fragment = "{/* %s */}" }`.

WebFetch https://raw.githubusercontent.com/folke/ts-comments.nvim/HEAD/README.md for the full default `lang` table — the project ships sensible coverage for nearly every embedded-language combo and you almost never need to override.

## Our config

`opts = {}` — accept the upstream default `lang` table. Nothing language-specific overridden.

## Keymaps

No bindings. Hooks into the builtin commenting commands via `vim.bo.commentstring`:

| Key | Mode | Builtin action |
|-----|------|----------------|
| `gcc` | n | toggle current line comment |
| `gc{motion}` | n | toggle motion range |
| `gc` | x | toggle selection |
| `gbc` | n | toggle blockwise comment |

## Links

- Plugin repo: https://github.com/folke/ts-comments.nvim
- Builtin commenting: `:help commenting`

## Notes

- Neovim ≥ 0.10 required (uses the new `vim._comment` API).
- Cooperates with `vim-matchup` and `nvim-treesitter` — no conflicts.
- If `gcc` ever produces the wrong style inside a JSX/Vue/Svelte buffer, run `:checkhealth nvim-treesitter` and confirm the parser is installed — ts-comments needs a working TS tree to inspect.
- This plugin replaces older solutions like `JoosepAlviste/nvim-ts-context-commentstring` and `numToStr/Comment.nvim` for the embedded-language case. We use neither here.
