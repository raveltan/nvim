# workflow-claude-code
> Toggleable in-Neovim terminal hosting Anthropic's `claude` CLI.

**Repo:** https://github.com/greggh/claude-code.nvim
**Local spec:** lua/plugins/workflow.lua:24-52
**Tags:** workflow claude ai terminal cli

## Scope
Lazy-loaded on `<leader>a*` keys. Spawns the `claude` binary in a vertical split (40% width), enters insert mode automatically, and refreshes buffers every second so files Claude edits show up in Neovim without a manual `:checktime`. Uses the git repo root as cwd so context is consistent across subdirectories.

## Install spec
```lua
{
  "greggh/claude-code.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "ClaudeCode", "ClaudeCodeContinue", "ClaudeCodeResume", "ClaudeCodeVerbose" },
  opts = {
    window = {
      split_ratio = 0.4,
      position = "vertical",
      enter_insert = true,
      start_in_normal_mode = false,
      hide_numbers = true,
      hide_signcolumn = true,
    },
    refresh = { enable = true, updatetime = 100, timer_interval = 1000, show_notifications = true },
    git = { use_git_root = true },
    command = "claude",
  },
}
```

## Common customizations
- `command` *(string, "claude")* — binary launched in the terminal. Override to point at a wrapper or `claude-code` build.
- `window.position` *("vertical"|"horizontal"|"float"|"tab", "vertical")* — split style. `"float"` opens a centered window; pair with `window.float = {...}`.
- `window.split_ratio` *(number 0..1, 0.4)* — fraction of screen the split takes.
- `window.enter_insert` *(bool, true)* — drop into insert mode on open.
- `window.start_in_normal_mode` *(bool, false)* — counterpart; setting `true` keeps you in normal mode.
- `window.hide_numbers` / `hide_signcolumn` *(bool)* — cosmetic; turns off `number`/`signcolumn` for the claude buffer.
- `refresh.enable` *(bool, true)* — polls files for external changes; needs `vim.o.autoread = true`.
- `refresh.updatetime` *(int ms, 100)* — temporarily lowered `updatetime` while the terminal is open (restored on close).
- `refresh.timer_interval` *(int ms, 1000)* — how often `:checktime` is fired.
- `refresh.show_notifications` *(bool, true)* — toast when a buffer reloads.
- `git.use_git_root` *(bool, true)* — cd into `git rev-parse --show-toplevel` before spawning. Falls back to cwd when not in a repo.

## Our config
Matches defaults plus explicit `command = "claude"` (no PATH ambiguity) and `git.use_git_root = true` so Claude sees the whole repo from any subdirectory. The four `cmd` entries are listed for lazy-loading; the keys map to the basic three plus verbose.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>ac` | n | `:ClaudeCode` | Toggle Claude Code window |
| `<leader>aC` | n | `:ClaudeCodeContinue` | Continue last session |
| `<leader>ar` | n | `:ClaudeCodeResume` | Resume a saved session (picker) |
| `<leader>av` | n | `:ClaudeCodeVerbose` | Toggle with `--verbose` flag |

## Links
- README: https://github.com/greggh/claude-code.nvim

## Notes
- Refresh polling fires `:checktime` on every buffer every second — fine for normal repos, can be noisy on huge ones. Disable via `refresh.enable = false` if it interferes.
- The plugin runs `claude` as a child process; on close it sends SIGTERM. Long-running sessions survive `:ClaudeCode` toggles because the toggle hides/shows the buffer rather than killing the process.
- Pair with the project-level `CLAUDE.md` and `~/.claude/projects/*/memory/MEMORY.md` to keep context across resumes.
