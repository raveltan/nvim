# workflow-emmet
> Expand CSS-like abbreviations into HTML/JSX/ERB/Vue/Svelte markup.

**Repo:** https://github.com/mattn/emmet-vim
**Local spec:** lua/plugins/emmet.lua:1-43
**Tags:** workflow emmet html jsx eruby vue svelte tsx

## Scope
Lazy-loaded by `ft` for ten markup-y filetypes. Leader key `<C-y>` then a trigger: `,` to expand the abbreviation under the cursor, `/` to comment, `n` to jump to the next edit point. Adds an `<leader>ce` shortcut that calls the expand plug for buffers of those filetypes.

## Install spec
```lua
{
  "mattn/emmet-vim",
  ft = { "html", "eruby", "css", "scss", "sass", "less",
         "javascriptreact", "typescriptreact", "vue", "svelte", "htmldjango" },
  init = function()
    vim.g.user_emmet_leader_key = "<C-y>"
    vim.g.user_emmet_settings = {
      indentation = "  ",
      eruby           = { extends = "html" },
      javascriptreact = { extends = "jsx" },
      typescriptreact = { extends = "jsx" },
      vue             = { extends = "html" },
      svelte          = { extends = "html" },
    }
    -- FileType autocmd binds <leader>ce → <plug>(emmet-expand-abbr)
  end,
}
```

## Common customizations
- `g:user_emmet_leader_key` *(string, "<C-Y>")* — prefix before every emmet command. Default already `<C-y>`; we set it explicitly for clarity.
- `g:user_emmet_settings` *(dict)* — per-filetype config. Top-level keys are filetypes; values can include `extends` (inherit another filetype's snippets), `indentation`, `snippets`, `aliases`, `default_attributes`, `filters`.
- `g:user_emmet_mode` *(string, "")* — restrict to `"n"`, `"i"`, `"v"` or `"a"` (all). Empty = all.
- `g:user_emmet_expandabbr_key`, `g:user_emmet_complete_tag` and similar — override individual command keys. Rarely needed.
- `g:user_emmet_install_global` *(0/1, 1)* — install globally vs only on `:EmmetInstall`. We rely on the default plus `ft` lazy-load.

## Our config
- Leader `<C-y>` (default) — sequences: `<C-y>,` expand, `<C-y>/` comment, `<C-y>n` next point, `<C-y>k` remove tag, `<C-y>d` balance tag.
- `indentation = "  "` (two spaces) for generated markup.
- `eruby` inherits HTML's snippet set — Rails `.html.erb` files get full emmet. ERB-specific `<%= %>` / `<% %>` are written by hand or via `vim-rails`.
- `javascriptreact` and `typescriptreact` inherit `jsx` — `className` instead of `class`, `htmlFor` instead of `for`, self-closing void tags.
- `vue` and `svelte` inherit `html` — full HTML snippets in `.vue` `<template>` blocks and `.svelte` files.
- `<leader>ce` bound buffer-locally via `FileType` autocmd to `<plug>(emmet-expand-abbr)` so you can expand without the two-stroke `<C-y>,`.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<C-y>,` | i, n | expand abbreviation | `ul>li.item*3` → list |
| `<C-y>/` | i, n | toggle comment | wrap selection in language-aware comment |
| `<C-y>n` | i, n | next edit point | jump cursor to next empty attr/tag |
| `<C-y>N` | i, n | prev edit point | reverse direction |
| `<C-y>d` | i, n | balance tag | select containing tag |
| `<C-y>k` | i, n | remove tag | delete containing tag, keep inner |
| `<leader>ce` | n (buf-local on the 10 fts) | `<plug>(emmet-expand-abbr)` | One-stroke expand |

## Links
- README: https://github.com/mattn/emmet-vim
- Emmet cheat sheet: https://docs.emmet.io/cheat-sheet/

## Notes
- For JSX/TSX, type abbreviations like `div.foo>span` and expand — emmet honors the `jsx` inheritance and uses `className=`.
- `htmldjango` is included for Django templates; same HTML inheritance.
- `eruby` filetype only triggers on `.erb` files when `g:rubycomplete_*` plugins or vim-rails populate the filetype. Otherwise Neovim sets `filetype=eruby.html` and emmet still works via the html branch.
- The autocmd registers `<leader>ce` only for matching buffer types — opening a `.lua` file won't shadow other `<leader>ce` bindings.
