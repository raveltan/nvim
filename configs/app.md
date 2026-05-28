# App stack — config mirror

This folder mirrors the dotfiles for the macOS rig. Edit live configs in their
real homes; this folder is a versioned snapshot for reference.

**Before first use:** see [`macos-preflight.md`](macos-preflight.md) for required
System Settings tweaks (separate Spaces, hidden menu bar, removed extra desktops, etc.).

**Keymap cheatsheet:** see [`keymaps.md`](keymaps.md).

## Window management & UI

- **AeroSpace** — tiling WM. Live config: `~/.aerospace.toml`. Mirror: `aerospace/aerospace.toml`.
  - Hyper (`⌃⌥⌘⇧`) + `hjkl` focus, Meh (`⌃⌥⇧`) + `hjkl` move.
  - Workspaces: `T` terminal, `B` browser, `D` docs, `C` comms, `N` notes.
  - Reload: `Hyper-;` then `Esc`, or `aerospace reload-config`.

- **JankyBorders** — colored ring on focused window. Live: `~/.config/borders/bordersrc`. Mirror: `borders/bordersrc`.
  - Started by AeroSpace via `after-startup-command`.

- **SketchyBar** — top bar. Live: `~/.config/sketchybar/`. Mirror: `sketchybar/`.
  - Workspace chips driven by `aerospace_workspace_change` event.
  - Reload: `sketchybar --reload`.

- **Ice** — tidies the native menu bar (mostly hidden, revealed at top edge).

## Launcher & clicking

- **Raycast** — `Alt-Space`. Disable its built-in window manager (AeroSpace owns layout).
- **Homerow** — `Space` to label clickable UI; `Shift-Space` for search; `Shift-J` for scroll.
- **Vimium** — browser link hints inside Chrome.

## Terminal layer

- **Ghostty** — `configs/ghostty/`. Native tabs disabled; tmux owns tabs.
- **tmux** — `configs/tmux/`. Prefix `Ctrl-Space`. `vim-tmux-navigator` glues panes to nvim splits.
- **Neovim** — `~/.config/nvim/`.

## Other

- **Capso** — screenshot tool
- **Mole** — app cleaner
- **Stats / AlDente** — optional menu-bar utilities

## Install (reminder)

```
brew install borders sketchybar
brew install --cask aerospace raycast homerow ghostty
```

Grant Accessibility to AeroSpace, Raycast, Homerow on first launch.

## Start services

```
aerospace                          # usually launched at login
borders                            # auto-started by aerospace
sketchybar                         # auto-started by aerospace
```

Or as background services:

```
brew services start sketchybar
brew services start borders
```

## Backups

Previous configs preserved at `~/.aerospace.toml.bak` and `~/.config/sketchybar.bak`.
