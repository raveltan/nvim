# Neovim Configuration

Modular, LSP-first Neovim built on [lazy.nvim](https://github.com/folke/lazy.nvim). Polyglot: TypeScript, PHP, Ruby on Rails, Python, Rust, Flutter, Swift/SwiftUI. Opt-in GAF profile (`GAF=1 nvim`).

## Install

```sh
git clone git@github.com:raveltan/nvim.git ~/.config/nvim
nvim
```

## Docs

- [`docs/nvimdocs/INDEX.md`](docs/nvimdocs/INDEX.md) — every plugin / module, grouped
- [`docs/keybinds.md`](docs/keybinds.md) — keybind cheatsheet
- [`docs/obsidian.md`](docs/obsidian.md) — Obsidian note-taking workflow guide
- [`docs/nvimdocs/config-init.md`](docs/nvimdocs/config-init.md) — bootstrap order
- [`docs/nvimdocs/gaf-overview.md`](docs/nvimdocs/gaf-overview.md) — GAF profile
- [`docs/nvimdocs/ruby-vim-rails.md`](docs/nvimdocs/ruby-vim-rails.md) — Rails navigation (vim-rails `:A`/`:R`/`:E*` + projections)

## Layout

- `init.lua` — entry
- `lua/config/` — options, lazy, keymaps, autocmds, smart rename (`rename.lua` + `scss.lua`)
- `lua/plugins/` — plugin specs (auto-imported)
- `lua/tagmatch/` — in-repo treesitter tag module (`%` jump, `i%`/`a%`, tag rename)
- `lua/gaf/` — GAF profile modules (gated on `vim.g.gaf`)
- `lua/overseer/template/user/` — task templates
- `after/ftplugin/` — per-filetype tweaks
- `snippets/` — LuaSnip JSON
- `scripts/` — shell helpers
- `docs/` — see [INDEX](docs/nvimdocs/INDEX.md)
