# nav-vim-tmux-navigator
> Seamless `<C-h/j/k/l>` window navigation that crosses the nvim/tmux boundary.

**Repo:** https://github.com/christoomey/vim-tmux-navigator
**Local spec:** lua/plugins/nav.lua:4-17
**Tags:** navigation, tmux, splits, window

## Scope
Unifies pane/split navigation between Neovim windows and tmux panes. Pressing `<C-h/j/k/l>` moves between nvim splits when an adjacent one exists, and falls through to the surrounding tmux pane when at the edge. Eliminates the cognitive split between vim's `<C-w>h` and tmux's prefix-based motions. Requires a small companion config in `~/.tmux.conf` (see plugin README).

## Install spec
```lua
{
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
  },
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Window left" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Window down" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Window up" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Window right" },
  },
}
```

## Common customizations
- `g:tmux_navigator_no_mappings` *(0/1, 0)* — disable default `<C-h/j/k/l>` mappings (we set this implicitly by using `cmd` + `keys` in lazy).
- `g:tmux_navigator_save_on_switch` *(0/1/2, 0)* — auto `:update`/`:wall` before leaving nvim for tmux.
- `g:tmux_navigator_disable_when_zoomed` *(0/1, 0)* — don't un-zoom a tmux pane when navigating.
- `g:tmux_navigator_preserve_zoom` *(0/1, 0)* — keep tmux zoom state when moving between panes.
- `g:tmux_navigator_no_wrap` *(0/1, 0)* — disable wrapping at the edges.

## Our config
Lazy-loads on the four `TmuxNavigate*` commands and the four `<C-*>` keys. No `opt`/`g:` overrides — vanilla behaviour. Companion tmux side lives in `~/.tmux.conf`, outside this repo.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<C-h>` | n | `:TmuxNavigateLeft` | Window/pane left |
| `<C-j>` | n | `:TmuxNavigateDown` | Window/pane down |
| `<C-k>` | n | `:TmuxNavigateUp` | Window/pane up |
| `<C-l>` | n | `:TmuxNavigateRight` | Window/pane right |

## Links
- README: https://github.com/christoomey/vim-tmux-navigator/blob/master/README.md

## Notes
- `<C-l>` here overrides nvim's default redraw — use `:redraw!` or `:mode` if a redraw is needed.
- oil.nvim disables its own `<C-h>`/`<C-l>` bindings (`nav.lua:35-36`) so this navigator wins inside Oil buffers.
- fff.nvim picker uses `<C-l>` to focus its result list, which only applies while the picker is open — the global mapping is restored on close.
- Without the matching tmux config, `<C-l>` at the edge of a tmux pane will not cross; tmux just receives a literal `C-l`.
