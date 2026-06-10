# ruby-vim-endwise
> Auto-inserts `end` after `def`/`do`/`if`/`class`/`module` (Ruby) and equivalents in other langs.

**Repo:** https://github.com/tpope/vim-endwise
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/rails.lua:161-164
**Tags:** ruby, lua, vim, shell, autoclose, tpope

## Scope
Hooks `<CR>` in insert mode. When the line being broken starts a block keyword (`def`, `do`, `if`, `unless`, `case`, `class`, `module`, `begin` for Ruby; `function`, `do`, `if` for Lua; `if`, `for`, `while`, `case` for sh), it inserts the matching closer (`end`, `fi`, `done`, `esac`) on the next blank line and parks the cursor between them. Detects nesting so it does not duplicate an existing `end`.

## Install spec
```lua
{
  "tpope/vim-endwise",
  ft = { "ruby", "eruby", "lua", "vim", "sh", "bash", "zsh" },
}
```

## Common customizations
- `g:endwise_no_mappings = 1` to skip the default `<CR>` mapping (then map `<Plug>DiscretionaryEnd` yourself). We do not set this.
- Filetype list — endwise has built-in support for ruby, eruby, lua, vimscript, sh/bash/zsh, vbnet, crystal, snippets, elixir, haskell, ocaml, matlab, tex, htmldjango, julia. We list only the ones we touch so loading stays lazy.
- WebFetch https://raw.githubusercontent.com/tpope/vim-endwise/HEAD/README.markdown if uncertain.

## Our config
Pure filetype lazy-load — no setup, no overrides.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<CR>` | i | endwise insert closer when on block-opening line | Auto `end` |

(`<CR>` is the built-in plugin mapping; no `<leader>` binding.)

## Links
- Plugin README: https://github.com/tpope/vim-endwise
- Companion: [[ruby-vim-rails]], [[ts-nvim-treesitter]] (treesitter-endwise alternative)

## Notes
- We previously used `nvim-treesitter-endwise` but it broke against the treesitter `main` branch (upstream regression as of late 2025) — comment in `lua/plugins/rails.lua:160` records the swap.
- Plays nicely with blink.cmp: endwise's `<CR>` triggers only when no completion item is selected, so completion `<CR>` accept still works.
- For Lua / Vimscript / shells we keep it active because the same heuristic gives `end` / `endfunction` / `fi` / `done` / `esac` cheaply with zero config drift.
