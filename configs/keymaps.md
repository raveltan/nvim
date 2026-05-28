# Keymap cheatsheet

**Hyper = `⌃⌥⌘⇧`** | **Meh = `⌃⌥⇧`** (Hyper minus Cmd)

Mnemonic: **Hyper = look** (focus), **Meh = carry** (move).

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
| `Hyper-B` | Browser (Chrome) — auto-launches |
| `Hyper-D` | Docs |
| `Hyper-C` | Comms (Slack) — auto-launches |
| `Hyper-N` | Notes |
| `Hyper-1..5` | Scratch workspaces |
| `Hyper-Tab` | Previous workspace (back-and-forth) |
| `Meh-T/B/D/C/N` | Send window to workspace + follow |

### Layout

| Keys | Action |
|---|---|
| `Hyper-/` | Toggle horizontal/vertical tiling |
| `Hyper-,` | Accordion layout |
| `Hyper-F` | Fullscreen (zoom focused window) |
| `Hyper-Space` | Toggle float/tile |
| `Hyper-.` | Move workspace to next monitor |

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
| `F` | Toggle floating/tiling layout |
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
