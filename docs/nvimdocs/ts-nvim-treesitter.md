# ts-nvim-treesitter
> Treesitter parser installer + highlighting/indent engine for Neovim.

**Repo:** https://github.com/nvim-treesitter/nvim-treesitter
**Local spec:** lua/plugins/treesitter.lua:3
**Tags:** treesitter, syntax, highlight, indent, parser

## Scope
Provides the parser-install command (`:TSUpdate`) and the runtime API used to start treesitter on a buffer (`vim.treesitter.start`) and drive indentation (`require('nvim-treesitter').indentexpr()`). This config uses the `main` branch API — no central `setup()` for highlight/indent; those are gated per-buffer in a `FileType` autocmd.

## Install spec
```lua
{
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({ ...parsers... })
    -- FileType autocmd starts treesitter + sets indentexpr per buffer
  end,
}
```

## Common customizations
- `install({...})` *(string[])* — async parser install list. Run via `:TSUpdate` or on config.
- `install_dir` *(string, default `stdpath('data')/site`)* — where parsers are stored. Not overridden here.
- Highlight is enabled per-buffer via `vim.treesitter.start(buf)`.
- Indent is enabled per-buffer via `vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"`.
- The legacy `ensure_installed`/`highlight = { enable = true }` table-style config is `master`-branch only; this config is `main`.

## Our config
- **Parsers installed:** `angular`, `bash`, `blade`, `css`, `dart`, `diff`, `embedded_template`, `html`, `javascript`, `json`, `lua`, `markdown`, `markdown_inline`, `php`, `php_only`, `python`, `regex`, `ruby`, `rust`, `scss`, `swift`, `tsx`, `typescript`, `vim`, `vimdoc`, `yaml`.
- Angular template injections come from mainline ECMA `injections.scm` — the archived `nvim-treesitter-angular` plugin is intentionally not added.
- **Indent skip list:** `ruby`, `eruby` — defers to vim's built-in `GetRubyIndent` (handles continuations, hanging args, hash rockets that the TS query misses).
- **Size guards:** skip TS for buffers `> 500 KiB` or `> 10000 lines` to avoid slow parse on generated/minified files.
- `vim.g.matchup_matchparen_deferred = 1` to engage vim-matchup treesitter integration.
- `lazy = false` — required; the plugin does not support lazy-loading.

## Keymaps
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| — | — | — | No direct mappings; see [ts-textobjects](ts-textobjects.md) for TS-driven keys. |

## Links
- README: https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
- Related: [ts-context](ts-context.md), [ts-textobjects](ts-textobjects.md), [ts-autotag](ts-autotag.md)

## Notes
- This is the `main` branch (modern API). Mixing `master`-branch docs/snippets will fail silently.
- `:TSUpdate` must be run after upgrading the plugin to refresh parser ABIs.
- The autocmd uses `pcall(vim.treesitter.start, ...)` so missing parsers degrade quietly to vim's regex syntax.
