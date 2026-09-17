# terminal-ghostty-tmux
> The terminal half of how this config looks: Ghostty transparency/contrast, tmux capability overrides, fonts, and the image-protocol chain.

**Local files:** `~/.config/ghostty/config`, `~/.config/tmux/tmux.conf` (both OUTSIDE this repo)
**Tags:** terminal, ghostty, tmux, transparency, undercurl, fonts, image

## Scope

Roughly half of this config's appearance is decided outside Neovim. The colorscheme asks for
transparency, the diagnostics ask for four distinct underline styles, `snacks.image` asks for a
graphics protocol, and `'guicursor'` asks for cursor-shape escapes — none of which Neovim can
provide by itself. This doc records what the terminal side must supply, and what is actually
installed on this machine.

## What is installed

| Terminal | Version | Role |
|---|---|---|
| **Ghostty** | 1.3.1 (Metal renderer) | **Daily driver.** `~/.config/ghostty/config` launches tmux directly via `command = /opt/homebrew/bin/tmux new-session -A -s main`. |
| kitty | 0.47.4 | Vestigial — `kitty.conf` has exactly one live line (`font_size 16.0`), everything else stock. Kept only as a fallback; it is the one terminal here with a native, cheap `cursor_trail`. |
| WezTerm | 20240203 build | Stale (~2 years behind current). Not a serious second choice unless upgraded. |

## The transparency contract

**This is the part that silently breaks.** `lua/plugins/ui.lua` sets
`require("luna").setup({ transparent = true })` and force-clears `bg` on Normal/NormalNC/SignColumn/
StatusLine/StatusLineNC/WinSeparator. That only produces a visible effect if the terminal
underneath is itself translucent. Before Aug 2026 the Ghostty config had `background-opacity`
commented out, so nvim was drawing "transparent" onto an opaque black window and the entire
transparency setup was inert.

```
background-opacity = 0.88
background-blur = 20
minimum-contrast = 1.2
unfocused-split-opacity = 0.6
window-padding-balance = true
macos-titlebar-style = hidden
```

- `background-blur` — **the correct key name.** `background-blur-radius` is the OLD name and is
  silently ignored by Ghostty 1.3.x; a config using it looks like transparency is broken for no
  reason. Takes an integer, or `true` (= 20).
- `minimum-contrast = 1.2` — the actual fix for the "washed-out" complaint people usually blame
  on opacity. Forces a WCAG contrast floor so luna's dim comment/hint greys stay legible
  against a blurred wallpaper. Lower toward `1.0` if colors start looking punched-up.
- `unfocused-split-opacity` — dims the inactive pane; meaningful because vim-tmux-navigator
  means several panes are usually open.
- Anything nvim deliberately keeps **opaque** (floats, Pmenu, TreesitterContext) is documented
  in [ui-luna](ui-luna.md) — transparent editor, solid overlays.

## tmux capability overrides

`TERM=tmux-256color` is correct for tmux, but it strips terminal-specific capability strings.
Each override below re-adds one thing Neovim depends on:

| Setting | What breaks without it |
|---|---|
| `default-terminal "tmux-256color"` | baseline |
| `terminal-overrides ",*256col*:Tc"` | 24-bit color — without it luna renders banded/wrong-hued |
| `terminal-overrides ',*:Smulx=\E[4::%p1%dm'` | undercurl, and with it the four **distinct** diagnostic underline styles (undercurl/underdouble/underdotted/underdashed) set in `lua/plugins/lsp.lua` |
| `terminal-overrides ',*:Setulc=...'` | undercurl *color* (severity color on the squiggle) |
| `terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'` | **DECSCUSR passthrough.** Without it `'guicursor'` never reaches Ghostty, so the block/bar-by-mode and the blink timings in `lua/config/options.lua` do nothing inside tmux. |
| `allow-passthrough on` | Kitty graphics protocol through tmux → `snacks.image` renders nothing |
| `escape-time 0` | laggy `<Esc>` in nvim |
| `focus-events on` | `FocusGained`/`FocusLost` autocmds, checktime-on-focus |

## tmux window naming (manual only)

Window names are **frozen** — tmux never renames a window on its own. Before Sep 2026 this
config had `automatic-rename on` with `automatic-rename-format '#{b:pane_current_path}'`, so
every window silently retitled itself to the cwd basename as you moved around; a name you set
by hand survived only until the next `cd`.

```
set -g automatic-rename off   # no retitle to cwd basename
set -g allow-rename off       # ignore OSC 0/2 title escapes from the shell or programs
```

Both are needed. `automatic-rename` is tmux's own cwd/command-based renaming; `allow-rename`
is the separate path where a program (a shell prompt writing `\033]2;...\007`, or nvim's
`'title'`) pushes a name in. Turning off only one leaves the other still overwriting the name.

The name is rendered at the **start of `status-right`**, immediately to the right of the window
numbers. Both lines sit **after** the `run '.../tpm'` line — the plugin sets `status-right`
itself at load, so an earlier `set` is discarded:

```
run-shell 'tmux show -gv @status_right_base >/dev/null 2>&1 || tmux set -g @status_right_base "$(tmux show -gv status-right)"'
run-shell 'tmux set -g status-right "#[fg=#9ccfd8,bold] ##W#[default]  $(tmux show -gv @status_right_base)"'
```

Why two `run-shell` lines instead of one `set -ga`:

- `status-right` has to be *prepended*, and tmux has no prepend. The first line caches
  rose-pine's own value in `@status_right_base` once; the second rebuilds `status-right` from
  that cache. Re-sourcing the config is therefore idempotent — without the cache, every
  `source-file` would stack another copy of `#W` on the bar.
- `$(tmux show -gv …)` runs in the shell, *after* format expansion, so the base string's
  `#{b:pane_current_path}` stays a live format instead of freezing to the current path.
- `##W` is doubled because `run-shell` expands formats in its command line; `##W` collapses to
  a literal `#W` that tmux then evaluates per-redraw. Style markers `#[…]` pass through
  `run-shell` untouched and must **not** be doubled.

Rename with prefix + `,` (tmux default, kept explicit with the current name prefilled):

```
bind , command-prompt -I "#{window_name}" -p "window name:" "rename-window '%%'"
```

Note the window list itself (`window-status-format`) still shows only `#I`, the window index —
the name appears once, on the right of the numbers, for the active window only. Bar layout:
`session │ 1 2 3 │ window-name  time  path`.

## Fonts — nothing to patch

Ghostty ≥ 1.2.0 ships its own standalone Symbols-Nerd-Font fallback and **auto-scales Nerd Font
glyphs to the cell size for any font**, patched or not; the Ghostty docs state there is no
longer a reason to use patched fonts. The configured font here is **Zenbones Brainy**
(an unpatched Iosevka variant), and every mini.icons / lualine / satellite / fidget glyph
renders because *Ghostty* supplies it, not the font.

Consequence: font choice is now purely about letterforms and ligatures, not icon coverage. Same
auto-fallback exists in kitty (≥0.28) and WezTerm.

```
font-family = Zenbones Brainy
font-size = 16
font-thicken = true
adjust-cell-height = 4
```

## Image protocol chain

`snacks.image` needs, in order: a capable terminal (kitty/ghostty/wezterm) → tmux
`allow-passthrough on` → external converters. Verified on this machine:

| Dependency | State | Enables |
|---|---|---|
| `magick` (ImageMagick) | present | png/jpg/gif/webp, PDF pages, video thumbnails |
| `mmdc` (mermaid-cli) | present | mermaid diagrams |
| `pdflatex` / `tectonic` | **missing** | LaTeX / math rendering in markdown — silently does nothing |
| `chafa` | missing | only needed for a `chafa`-based dashboard `terminal` section |

Run `:checkhealth snacks` to re-verify; a missing converter is a silent no-render, not an error.

## Known mismatch (open, deliberate)

Ghostty's 16-color palette is **Rose Pine Moon** (`cursor-color = a277ff` = iris, matching
`tmux.conf`'s `@rose_pine_variant 'moon'`), while Neovim runs **luna**. Anywhere ANSI colors
pass through unmapped — `:terminal`, lazygit, `Snacks.terminal`, fidget spinners — you see Rose
Pine, not luna. Fixing it means either repainting the 16 palette entries to luna (and
desyncing the tmux rose-pine statusline) or switching the nvim colorscheme. Left as-is.

## Gotchas

- **`TERM_PROGRAM` becomes `tmux`**, masking the real terminal. Anything that sniffs
  `TERM_PROGRAM` to detect Ghostty/kitty misdetects inside tmux. `snacks.image` handles this
  itself, with `SNACKS_GHOSTTY=true` as the documented escape hatch if detection ever fails.
- **`xterm-ghostty` over SSH** — remote hosts lack that terminfo entry and nvim fails with
  `Error opening terminal: xterm-ghostty`. One-time fix per host:
  `infocmp -x xterm-ghostty | ssh HOST -- tic -x -`. Rarely bites here because Ghostty launches
  tmux immediately, so sessions are `tmux-256color`.
- **Cursor trail**: Ghostty 1.3.1 has **no native** `cursor-trail`. 1.3.0 only added shader
  uniforms (cursor shape/position/time) so community GLSL can draw one, and maintainers' own
  threads report GPU usage near 100% with those shaders. kitty's native `cursor_trail 3` is the
  cheap implementation. Neither is configured; smear-cursor.nvim is not installed.
- Reload after editing: Ghostty ⌘⇧, — tmux `tmux source ~/.config/tmux/tmux.conf`.

## Links

- Ghostty config reference: https://ghostty.org/docs/config/reference
- Ghostty 1.2.0 notes (Nerd Font fallback): https://ghostty.org/docs/install/release-notes/1-2-0
- Ghostty terminfo over SSH: https://ghostty.org/docs/help/terminfo
- snacks.image requirements: https://github.com/folke/snacks.nvim/blob/main/docs/image.md
- Related: [ui-luna](ui-luna.md), [config-options](config-options.md), [nav-vim-tmux-navigator](nav-vim-tmux-navigator.md), [snacks-misc](snacks-misc.md)

## Notes

- These two files are **not** in this repo. Changes here are not covered by the nvim config's
  git history — check them by hand when the UI looks wrong for no in-nvim reason.
- Diagnostic underline styles, `'guicursor'` and transparency are the three features that fail
  *silently and invisibly* when the terminal side regresses. Suspect this doc first.
