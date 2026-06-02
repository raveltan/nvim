# App stack — config mirror

This folder mirrors the dotfiles for the macOS rig. Edit live configs in their
real homes; this folder is a versioned snapshot for reference.

**Before first use:** see [`macos-preflight.md`](macos-preflight.md) for required
System Settings tweaks (separate Spaces, hidden menu bar, removed extra desktops, etc.).

**Keymap cheatsheet:** see [`keymaps.md`](keymaps.md).

## Window management & UI

- **AeroSpace** — tiling WM. Live config: `~/.aerospace.toml`. Mirror: `aerospace/aerospace.toml`.
  - Hyper (`⌃⌥⌘⇧`) + `hjkl` focus, Meh (`⌃⌥⇧`) + `hjkl` move.
  - Workspaces: `T` terminal, `B` browser, `D` docs, `C` comms (Claude + Rocket.Chat), `N` notes.
  - **3-display desk — one screen, one role** (`[workspace-to-monitor-force-assignment]`):
    - `built-in` (laptop) → **C** comms + **N** notes + **1**: Claude desktop + Rocket.Chat. Eyes-on screen for chat/AI while working.
    - `DELL U2715H (1)` → **T** + **D** + **2**/**3**: coding (Ghostty, editors).
    - `DELL U2715H (2)` → **B** + **4**/**5**: browser testing (Chrome / Firefox).
    - **Why name-regex, not `main`/`secondary`:** those keywords give only 2 buckets — with 3 monitors the 3rd is unaddressed and windows scatter to auto-created workspaces (`6`/`7`). Matching by monitor name is the only way to pin 3 distinct roles.
    - **Escaping:** patterns are regex inside **single-quoted** TOML (literal), so parens stay escaped — `'DELL U2715H \(1\)'`. Double quotes choke on `\(`. The two DELLs share a base name; the `\(1\)`/`\(2\)` suffix is what AeroSpace appends to disambiguate dupes, required to tell them apart.
    - **Undock fallback:** each external workspace is a list `['DELL …', 'built-in']` → drops to laptop when the screen's gone. Laptop workspaces are bare strings. No reconfig laptop↔dock.
    - **Wrong external?** `\(1\)`/`\(2\)` is AeroSpace's order, not physical left/right — swap the two DELL blocks (one edit) if code/browser land on the wrong screen.
    - **App auto-placement** (`[[on-window-detected]]`): Claude/Rocket/Discord → `C`, Ghostty → `T`, Chrome/Firefox → `B`. New windows route on open; pre-existing windows need one manual move.
    - macOS **menu-bar "main display"** is a separate System Settings thing (Displays → drag white bar), unrelated to this pinning.
  - **Top gap is per-monitor** (`[gaps] outer.top` array) so SketchyBar clears correctly on both notch and non-notch screens:
    - `{ monitor.'built-in' = 8 }` — notch screen's tall menu bar is already excluded from `visibleFrame`, so only a small gap is needed; a fixed value here double-gaps.
    - `44` (default) — external/no-notch monitors: SketchyBar (`position=top height=40`) sits at `y=0`, so the gap must cover the full bar height + pad or the bar gets hidden under the top window.
    - Last array item **must be a bare Int** (the default); a `monitor.'.*'` object there fails to parse.
    - Symptom if wrong: single fixed `outer.top` → extra space on notch displays, bar covered on non-notch.
  - Reload: `Hyper-;` then `Esc`, or `aerospace reload-config`.

- **JankyBorders** — colored ring on focused window. Live: `~/.config/borders/bordersrc`. Mirror: `borders/bordersrc`.
  - Started by AeroSpace via `after-startup-command`.

- **SketchyBar** — top bar. Live: `~/.config/sketchybar/`. Mirror: `sketchybar/`.
  - Workspace chips driven by `aerospace_workspace_change` event.
  - **devbox item** — remote dev box health. Plugin `sketchybar/plugins/devbox.sh`
    runs `script/checkdevbox.sh` every 30s; green=up, yellow=provisioning, red=down.
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

## Scripts

Helper scripts live in `script/`. Real home is `~/.config/nvim/configs/script/`.

- **`checkdevbox.sh`** — SSHes to the remote dev box, reports `UP` / `PROVISIONING`
  (muppet running) / `DOWN` (unreachable). Consumed by the SketchyBar devbox item.
  - Expects an SSH key at `~/.ssh/id_ed25519` (**not** committed here — key stays local).
  - Edit `REMOTE_HOST` at the top to retarget.

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
