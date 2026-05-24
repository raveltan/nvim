# Neovim Configuration

Modular, LSP-first Neovim built on [lazy.nvim](https://github.com/folke/lazy.nvim). Polyglot: TypeScript, PHP, Ruby on Rails, Python, Rust, Flutter. Opt-in GAF profile (`GAF=1 nvim`).

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

## Layout

- `init.lua` — entry
- `lua/config/` — options, lazy, keymaps, autocmds
- `lua/plugins/` — plugin specs (auto-imported)
- `lua/gaf/` — GAF profile modules (gated on `vim.g.gaf`)
- `lua/overseer/template/user/` — task templates
- `after/ftplugin/` — per-filetype tweaks
- `snippets/` — LuaSnip JSON
- `scripts/` — shell helpers
- `docs/` — see [INDEX](docs/nvimdocs/INDEX.md)
