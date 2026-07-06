# cmp-blink
> Rust-fuzzy completion engine driving LSP/snippet/path/buffer sources.

**Repo:** https://github.com/saghen/blink.cmp
**Local spec:** lua/plugins/lsp.lua:333
**Tags:** completion, lsp, snippets, fuzzy, ui

## Scope

`blink.cmp` is the autocomplete front-end. It pulls candidates from LSP, snippets (LuaSnip), filesystem paths, and the current buffer, then ranks them with a native Rust SIMD fuzzy matcher. It also renders the completion menu, ghost text, signature help, and documentation popup.

## Install spec

```lua
{
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "1.*",
  dependencies = { "rafamadriz/friendly-snippets", "L3MON4D3/LuaSnip", "onsails/lspkind.nvim" },
  opts = function() return { ... } end,
}
```

Pinned to `1.*`. Lazy-loaded on `InsertEnter` so startup stays cheap.

## Common customizations

- `keymap.preset` *(string, "default")* — base keymap (`default`, `super-tab`, `enter`, `none`). We use `default` and overlay individual keys.
- `snippets.preset` *(string, "default")* — snippet engine bridge (`default` | `luasnip` | `mini_snippets`).
- `sources.default` *(string[], {"lsp","path","snippets","buffer"})* — provider list in priority order.
- `sources.providers.<name>.max_items` *(integer)* — cap items per provider.
- `completion.list.selection.preselect` *(bool, true)* — auto-highlight first item.
- `completion.list.selection.auto_insert` *(bool, true)* — insert highlighted item into buffer as you scroll. We set `false` to avoid stray text on `<Esc>`.
- `completion.menu.auto_show` *(bool, true)* — show menu without explicit trigger.
- `completion.menu.draw.columns` *(table[])* — column layout for the popup.
- `completion.documentation.auto_show` *(bool, false)* — auto-open doc panel beside menu.
- `completion.ghost_text.enabled` *(bool, false)* — inline preview of the selected item.
- `signature.enabled` *(bool, false)* — opt-in signature help popup.
- `fuzzy.implementation` *(string, "prefer_rust_with_warning")* — `rust` | `prefer_rust` | `lua`. We use `prefer_rust` to silently fall back if the prebuilt binary is missing.
- `appearance.nerd_font_variant` *(string, "mono")* — kind-icon spacing.

## Our config

- Disabled in `grug-far` buffers (interferes with search input).
- `<C-Space>` shows/hides menu and doc.
- `<CR>` has a smart-pair handler: if cursor sits between matching `()`, `[]`, or `{}` and menu is hidden, it splits the pair onto two lines (`<CR><C-o>O`); otherwise accept selection then fallback.
- Snippet preset = `luasnip` (see [[cmp-luasnip]]).
- Kind icons sourced from `lspkind.symbol_map`.
- Menu and doc windows use `rounded` border, `winblend = 0`, scrollbar off.
- `completion.trigger.*` flags are explicitly pinned (defaults that match upstream) so future blink upgrades don't silently change trigger behaviour.
- `list.selection.preselect = true`, `auto_insert = false` — first item highlighted, nothing inserted until accept.
- `sources.providers.lsp.max_items = 50` to keep large workspaces from flooding the menu.
- Fuzzy uses `prefer_rust` (Rust SIMD matcher with Lua fallback).

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<C-Space>` | i | show / hide / show_documentation / hide_documentation | Toggle menu and doc panel |
| `<CR>` | i | smart-pair / accept / fallback | Split empty bracket pair; otherwise accept selection |
| `<C-n>` / `<C-p>` | i | select_next / select_prev | Default preset |
| `<Tab>` / `<S-Tab>` | i | snippet_forward / snippet_backward | Default preset (jumps LuaSnip tabstops) |
| `<C-e>` | i | hide | Default preset |
| `<C-y>` | i | accept | Default preset |

## Links

- Plugin repo: https://github.com/saghen/blink.cmp
- Default keymap presets: https://cmp.saghen.dev/configuration/keymap.html
- Source providers: https://cmp.saghen.dev/configuration/sources.html

## Notes

- The `<CR>` handler returns `false` from the function form to chain to subsequent entries (`"accept"`, `"fallback"`) — that's how blink composes multi-action keymaps.
- `build = "make install_jsregexp"` lives on the LuaSnip spec, not here — blink ships its own prebuilt Rust binary via lazy.nvim's `:Lazy build`.
- If you ever see "fuzzy matcher fell back to Lua" warnings, run `:Lazy build blink.cmp`.
