# nav-fff
> Fast fuzzy file finder + live grep backed by a Rust binary, with frecency ranking.

**Repo:** https://github.com/dmtrKovalenko/fff.nvim
**Local spec:** lua/plugins/fff.lua:1-50
**Tags:** picker, fuzzy, grep, frecency, files

## Scope
A single-purpose picker focused on the two most-common motions: "find a file" and "grep a string". Uses a precompiled Rust binary for indexing/matching, ranks results by frecency (recency + frequency) plus git status, and exposes live grep with smart-case + a time budget. Stands in for telescope/snacks-picker file/grep use cases; not a general picker framework.

## Install spec
```lua
{
  "dmtrKovalenko/fff.nvim",
  version = "*",
  build = function() require("fff.download").download_or_build_binary() end,
  cmd = { "FFFScan", "FFFRefreshGit", "FFFClearCache", "FFFHealth", "FFFDebug", "FFFOpenLog" },
  keys = { ... },           -- see Keymaps below
  opts = {
    prompt = "  ",
    title = " Files",
    max_results = 100,
    layout = {
      height = 0.85, width = 0.85,
      prompt_position = "top", preview_position = "right",
      preview_size = 0.55,
      flex = { size = 130, wrap = "top" },
    },
    preview = { line_numbers = true },
    keymaps = { focus_list = "<C-l>", focus_preview = "<C-p>", preview_scroll_up = "<M-u>" },
    frecency = { enabled = true },
    history = { enabled = true },
    grep = { smart_case = true, time_budget_ms = 200 },
  },
}
```

## Common customizations
- `max_results` *(int, 100)* — cap on shown matches; higher = slower repaint.
- `layout.preview_position` *("right"|"bottom"|"none")* — preview placement.
- `layout.preview_size` *(0-1, 0.5)* — fraction of the picker reserved for preview.
- `layout.flex` *(table)* — responsive layout: swap to a stacked layout below `size` cols.
- `preview.line_numbers` *(bool, false)* — show line numbers in the preview pane.
- `preview.imagemagick` *(bool)* — enable image preview (needs `magick` CLI).
- `frecency.enabled` *(bool, true)* — score by visit history.
- `history.enabled` *(bool, true)* — remember last query per call site.
- `grep.smart_case` *(bool, true)* — case-insensitive unless query has uppercase.
- `grep.time_budget_ms` *(int)* — abort a grep pass that exceeds this budget.
- `grep.modes` *({"smart","fuzzy","plain","regex"})* — search algorithms to cycle through.
- `keymaps` *(table)* — picker-internal bindings (`focus_list`, `focus_preview`, `select`, etc.). WebFetch https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/HEAD/README.md if uncertain.

## Our config
- Tall 85%/85% float with a top prompt and right-side preview at 55%.
- `flex.size = 130` — switch to wrap layout under 130 cols.
- `<C-l>` focuses the result list, `<C-p>` focuses the preview (note: `<C-l>` here only applies inside the picker, so vim-tmux-navigator is unaffected globally).
- `preview_scroll_up` remapped to `<M-u>` so the picker's input prompt `<C-u>` falls through to the native prompt-buftype "delete to prompt boundary" — i.e. clear the query.
- `<leader><leader>` and `<leader>sg` remember their last query across closes: the picker's `close` is wrapped once to snapshot `state.query` into a module-level table keyed by mode (`files`/`grep`), and those two keymaps reopen with `query = last_query[mode]`. All other keys are unwrapped and behave like a fresh launch.
- Frecency + per-call history on, grep is smart-case with a 200ms budget.
- `build` runs `fff.download.download_or_build_binary` — pulls a prebuilt binary or compiles locally on install/update.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader><leader>` | n | `fff.find_files({ query = last_query.files })` | Find files, resumes last query |
| `<leader>ff` | n | `fff.find_files()` | Find files (fresh, no resume) |
| `<leader>fd` | n | `fff.find_files_in_dir(%:p:h)` | Files in current buffer's dir |
| `<leader>fc` | n | indexes `stdpath("config")` then restores cwd on close | Files in nvim config |
| `<leader>sg` | n | `fff.live_grep({ query = last_query.grep })` | Live grep cwd, resumes last query |
| `<leader>sw` | n / x | `fff.live_grep({ query = <cword> })` | Grep word under cursor / selection |
| `<leader>sz` | n | `fff.live_grep({ grep.modes = {"fuzzy","plain"} })` | Fuzzy grep |
| `<leader>s.` | n | `fff.live_grep({ cwd = %:p:h })` | Grep in current file's dir |
| `<leader>gs` | n | open picker, feed `git:modified ` | Filter to git-modified files |
| `<C-l>` | i (picker) | focus list | Move focus to result list |
| `<C-p>` | i (picker) | focus preview | Move focus to preview pane |
| `<C-u>` | i (picker) | clear query | Native prompt-buftype "delete to prompt boundary" |
| `<M-u>` | i (picker) | scroll preview up | Remapped from `<C-u>` to free that key |

## Links
- README: https://github.com/dmtrKovalenko/fff.nvim/blob/main/README.md
- Default opts: https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/config.lua
- `:FFFHealth` — verifies the Rust binary and git index are healthy.

## Notes
- `<leader>fc` is non-trivial: it swaps the indexing dir to `~/.config/nvim`, then a one-shot `WinClosed` autocmd restores the original cwd via `change_indexing_directory`. Without this the picker would keep indexing the nvim config after closing.
- `<leader>gs` opens the picker and asynchronously injects the `git:modified ` filter via `nvim_feedkeys` on the next tick — leverages the picker's query DSL.
- Picker query supports prefix filters like `git:modified`, `git:staged`, `path:foo/` — see README "query syntax".
- Build step is required on first install and after updates; `:FFFHealth` reports binary version.
