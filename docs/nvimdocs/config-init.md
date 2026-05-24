# config-init
> Entrypoint: sets the GAF flag, hushes LSP logs, then loads each config module in order.

**Local file:** init.lua
**Tags:** config, bootstrap, gaf

## Scope

`init.lua` is the first file Neovim sources. It deliberately does almost nothing on its own — it only sets two globals and then hands off to `lua/config/*` modules and the GAF profile. Each `require` is a single line so the boot order is obvious at a glance.

## Highlights

- `vim.g.gaf = vim.env.GAF == "1"` — single source of truth for "is this the Freelancer profile". Every GAF-only plugin spec and keymap branch checks this global. See memory `nvim_gaf_profile.md`.
- `vim.lsp.log.set_level(vim.log.levels.ERROR)` — keeps `~/.local/state/nvim/lsp.log` from filling up with INFO chatter from intelephense and ts_ls. Set before any LSP attaches.
- Boot order is intentional:
  1. `config.options` — sets `mapleader` first so subsequent `<leader>…` mappings resolve correctly.
  2. `config.lazy` — bootstraps lazy.nvim and imports all plugin specs (plugins must exist before keymaps can reference them).
  3. `config.keymaps` — global mappings; some reference plugin globals like `Snacks` and `require("hlslens")`.
  4. `config.autocmds` — patches `vim.lsp.util.open_floating_preview` (must run after Neovim's LSP module is loaded, which lazy may have already touched).
  5. `gaf.setup()` — applies the GAF-specific overlay; internally no-ops when `vim.g.gaf` is false.

## Full listing

```lua
vim.g.gaf = vim.env.GAF == "1"

vim.lsp.log.set_level(vim.log.levels.ERROR)

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("gaf").setup()
```

## Links

- Related [config-options](config-options.md)
- Related [config-lazy](config-lazy.md)
- Related [config-keymaps](config-keymaps.md)
- Related [config-autocmds](config-autocmds.md)
- GAF overlay entrypoint lives in `lua/gaf/init.lua`

## Notes

- The `GAF` env var is read once at startup; flipping it requires restarting Neovim.
- `mapleader` is `<Space>` and is set inside `config.options`, not here, but it must be set before `config.keymaps` runs — keep `options` first in the boot order.
- If you ever add a new top-level module (e.g. `config.colorscheme`), insert it where its dependencies are satisfied — colorscheme typically goes after `lazy` so its plugin is installed.
