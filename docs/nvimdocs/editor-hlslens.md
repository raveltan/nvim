# editor-hlslens
> Floating "1/27" virt-text overlay on every search match, plus relative offsets.

**Repo:** https://github.com/kevinhwang91/nvim-hlslens
**Local spec:** lua/plugins/editor.lua:191
**Tags:** search, hlsearch, ui, virt-text, editor

## Scope

`nvim-hlslens` enhances `hlsearch` by painting a small "current-index / total" badge on the line of the current match and relative-position labels on nearby matches. It plays well with `*`, `#`, `n`, `N`, `/`, `?`, and integrates with plugins like `vim-asterisk` or `flash`.

## Install spec

```lua
{
  "kevinhwang91/nvim-hlslens",
  event = "VeryLazy",
  config = true,
}
```

`config = true` runs `require("hlslens").setup()` with defaults. Loaded after startup to keep the cold-path cheap.

## Common customizations

- `auto_enable` *(bool, true)* — start highlighted the moment you search.
- `enable_incsearch` *(bool, true)* — also draw lens while `incsearch` is composing the query.
- `calm_down` *(bool, false)* — hide lens once the cursor moves off the current match (less visual noise).
- `nearest_only` *(bool, false)* — only label the closest match instead of all visible ones.
- `nearest_float_when` *(string, "auto")* — `auto` | `always` | `never`; controls the float popup for the nearest hit.
- `float_shadow_blend` *(integer, 50)* — 0–100 transparency for the nearest float.
- `virt_priority` *(integer, 100)* — extmark priority for the lens labels.
- `build_position_cb` *(function|nil)* — callback receiving `{ start_pos, end_pos, nearest, idx, r_idx }` so you can pipe match positions into a quickfix-like plugin (e.g. scrollbar-marks).
- `override_lens(render, posList, nearest, idx, r_idx)` — fully custom renderer.

WebFetch https://raw.githubusercontent.com/kevinhwang91/nvim-hlslens/HEAD/README.md for the exhaustive list.

## Our config

Just `config = true` — pure defaults. We don't override `n`/`N` (the plugin works fine via its `on_key` autocommand without remapping search keys). No nearest-only, no calm_down.

If you ever want the classic "remap `n`/`N` to recenter + show lens" wiring, add:

```lua
vim.keymap.set("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]])
vim.keymap.set("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]])
```

## Keymaps

No bindings — operates via autocommands on the builtin search.

## Links

- Plugin repo: https://github.com/kevinhwang91/nvim-hlslens

## Notes

- Requires `set hlsearch` (Neovim default). Toggling `:nohlsearch` hides the lens until the next search.
- Cooperates with `flash.nvim` — flash supplies its own search labels in jump mode; hlslens kicks in once you commit.
- If labels look stale during fast typing in `/`, set `enable_incsearch = false`.
