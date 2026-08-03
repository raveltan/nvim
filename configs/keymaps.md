# Keymap cheatsheet

**Hyper = `⌃⌥⌘⇧`** | **Meh = `⌃⌥⇧`** (Hyper minus Cmd)

Mnemonic: **Hyper = look** (focus), **Meh = carry** (move).

---

## Quickstart — daily drivers

Five things to memorize first. Everything else is sugar.

| Keys | Action |
|---|---|
| `Hyper-h/j/k/l` | Move focus (window to window, monitor to monitor) |
| `Meh-h/j/k/l`   | Move window in direction |
| `Hyper-T`       | Terminal workspace (auto-launch Ghostty) |
| `Hyper-B`       | Browser workspace (no auto-launch) |
| `Hyper-C`       | Comms workspace (auto-launch Rocket.Chat) |
| `Hyper-\`       | Tile (side-by-side layout) |
| `Hyper-A`       | Toggle tiles ↔ accordion (stack) |

That's the loop: jump workspace → focus around with hjkl → tile or tab when crowded.

---

## AeroSpace — outside terminal

### Focus / move

| Keys | Action |
|---|---|
| `Hyper-h/j/k/l` | Focus window left/down/up/right (crosses monitors, wraps) |
| `Meh-h/j/k/l` | Move window left/down/up/right within workspace |

### Workspaces (letter mnemonics)

| Keys | Action |
|---|---|
| `Hyper-T` | Terminal (Ghostty) — auto-launches if not running |
| `Hyper-B` | Browser (Chrome) — switch only, no auto-launch |
| `Hyper-D` | Docs |
| `Hyper-C` | Comms (Rocket.Chat) — auto-launches |
| `Hyper-N` | Notes |
| `Hyper-1..5` | Scratch workspaces |
| `Hyper-Tab` | Previous workspace (back-and-forth) |
| `Meh-T/B/D/C/N` | Send window to workspace + follow |

### Layout

| Keys | Action |
|---|---|
| `Hyper-\` | Tile side-by-side (h_tiles) |
| `Hyper--` | Tile stacked up/down (v_tiles) |
| `Hyper-/` | Toggle horizontal/vertical tiling |
| `Hyper-,` | Accordion layout |
| `Hyper-A` | Toggle focused container: tiles ↔ accordion (stack) |
| `Hyper-F` | Fullscreen (zoom focused window) |
| `Hyper-.` | Move workspace to next monitor |

> `Hyper-Space` (float/tile toggle) is **disabled** — commented out in `~/.aerospace.toml`. Use service mode `Hyper-;` then `f` instead.

### Resize mode

`Hyper-R` → enters resize mode. Stays until `Esc` / `Enter`.

| Key | Action |
|---|---|
| `h` | Width -50px |
| `l` | Width +50px |
| `j` | Height +50px |
| `k` | Height -50px |
| `Esc` / `Enter` | Exit |

### Service mode

`Hyper-;` → enters service mode. Each command auto-exits back to main.

| Key | Action |
|---|---|
| `Esc` | Reload config |
| `R` | Flatten / reset workspace tree |
| `F` | Toggle floating/tiling layout (only float/tile toggle — `Hyper-Space` is disabled) |
| `Backspace` | Close all windows but current |
| `Meh-h/j/k/l` | Join focused window with neighbor |

---

## Raycast / Homerow

| Keys | Action | Tool |
|---|---|---|
| `Alt-Space` | Launcher | Raycast |
| `Hyper-V` | Clipboard history | Raycast |
| `Hyper-W` | Switch windows (Aerospace ext) | Raycast |
| `Hyper-S` | Snippets | Raycast |
| `Space` | Label clickable UI | Homerow |
| `Shift-Space` | Search mode | Homerow |
| `Shift-J` (after `Space`) | Scroll mode | Homerow |

---

## Inside Ghostty

| Keys | Action | Tool |
|---|---|---|
| `Ctrl-h/j/k/l` | Move between tmux panes ↔ nvim splits | vim-tmux-navigator |
| `Ctrl-Space` | tmux prefix | tmux |
| `<prefix> -` | Horizontal split | tmux |
| `<prefix> \|` | Vertical split | tmux |
| `<prefix> c` | New tmux window | tmux |
| `<prefix> n/p` | Next/prev tmux window | tmux |
| `<prefix> T` | sesh project picker | tmux |
| `<prefix> I` | Install tmux plugins | TPM |

### Floating terminal (floax)

Float = popup attached to a separate `scratch` session. Status bar shows window numbers (re-enabled via `client-attached` hook — floax disables it by default).

| Keys | Action |
|---|---|
| `<prefix> p` | Toggle float on/off |
| `<prefix> c` | New window **inside float** |
| `Alt-1..5` / `<prefix> n/p` | Switch float windows |
| `<prefix> P` | Float menu (resize/fullscreen/embed) |
| `C-M-e` | Embed float window into current session |

Multiple windows live in one float — numbers in the status bar tell them apart.

---

## Inside Chrome

| Keys | Action | Tool |
|---|---|---|
| `f` | Click link hint | Vimium |
| `F` | Click link hint (new tab) | Vimium |
| `gi` | Focus first input | Vimium |
| `J` / `K` | Prev/next tab | Vimium |
| `t` / `x` | New / close tab | Vimium |
| `o` / `b` | Search history / bookmarks | Vimium |
| `H` / `L` | Back / forward (custom) | Vimium |
| `d` / `u` | Close / restore tab (custom) | Vimium |
| `?` | Show all Vimium bindings | Vimium |

---

## Reserved combos — DO NOT REBIND

- `Alt-b`, `Alt-f`, `Alt-d` — shell word motion
- `Cmd-c/v/w/t/q/...` — macOS native
- `Ctrl-h/j/k/l` outside aerospace's Hyper namespace — sacred to tmux/nvim
