# editor-todo-comments
> Highlight TODO/FIX/HACK/NOTE/WARN/PERF comments and surface them in a picker.

**Repo:** https://github.com/folke/todo-comments.nvim
**Local spec:** lua/plugins/editor.lua:111-118
**Tags:** todo, comments, picker, highlight, editor

## Scope

`todo-comments.nvim` scans buffers for keyword comments (`TODO:`, `FIX:`, `HACK:`, `WARN:`, `PERF:`, `NOTE:`, `TEST:`, ...) and applies a coloured sign + matching highlight to each line. It also exposes a ripgrep-backed search so you can list every TODO across the workspace and jump to one.

## Install spec

```lua
{
  "folke/todo-comments.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {},
  keys = {
    { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo comments" },
  },
}
```

Lazy on `VeryLazy` (after UI). The picker keymap is routed through Snacks rather than the plugin's own `:TodoTelescope` / `:TodoTrouble` commands.

## Common customizations

- `signs` *(bool, true)* — show sign-column markers.
- `sign_priority` *(integer, 8)*.
- `keywords` *(table)* — map of keyword → `{ icon, color, alt = {...} }`. Defaults cover TODO, FIX (`FIXME`/`BUG`/`FIXIT`/`ISSUE`), HACK, WARN (`WARNING`/`XXX`), PERF (`OPTIMIZE`/`PERFORMANCE`), NOTE (`INFO`), TEST (`TESTING`/`PASSED`/`FAILED`).
- `gui_style` *(table, { fg="NONE", bg="BOLD" })* — vim gui flags applied to keyword fg/bg.
- `merge_keywords` *(bool, true)* — your `keywords` extend defaults rather than replace.
- `highlight.multiline` *(bool, true)* — extend highlight to multi-line comments.
- `highlight.multiline_pattern` *(string, "^.")*.
- `highlight.multiline_context` *(integer, 10)*.
- `highlight.before` *(string, "")* — `fg` | `bg` | `""` — style of the text before the keyword.
- `highlight.keyword` *(string, "wide")* — `fg` | `bg` | `wide` | `wide_bg` | `wide_fg` | `""`.
- `highlight.after` *(string, "fg")* — style of the message after the keyword.
- `highlight.pattern` *(string|string[], [[.*<(KEYWORDS)\s*:]])* — vim regex picking out keywords. Add `(...)` group around `KEYWORDS` for filetypes with non-`:` markers.
- `highlight.comments_only` *(bool, true)* — only match inside treesitter `comment` nodes.
- `highlight.max_line_len` *(integer, 400)*.
- `highlight.exclude` *(string[], {})* — filetypes to skip.
- `colors` *(table)* — keyword color → list of highlight groups to source the actual colour from (`error = { "DiagnosticError", "ErrorMsg", "#DC2626" }`).
- `search.command` *(string, "rg")* — search tool.
- `search.args` *(string[])* — defaults to a sensible `rg` invocation for `:TodoQuickFix`/etc.
- `search.pattern` *(string, [[\b(KEYWORDS):]])* — ripgrep regex.

WebFetch https://raw.githubusercontent.com/folke/todo-comments.nvim/HEAD/README.md if option keys drift.

## Our config

`opts = {}` — full defaults. The only customisation is the keymap, which calls `Snacks.picker.todo_comments()` instead of the plugin's bundled `:TodoTelescope`. Snacks integrates with the plugin's keyword list automatically.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>st` | n | `Snacks.picker.todo_comments()` | Picker over all TODO/FIX/HACK/... comments in workspace |

The plugin's own commands are also available without binding:

- `:TodoQuickFix` / `:TodoLocList` — load into quickfix / loclist.
- `:TodoTelescope` — only if telescope is installed.
- `:TodoTrouble` — if `folke/trouble.nvim` is installed.

## Links

- Plugin repo: https://github.com/folke/todo-comments.nvim
- Snacks picker integration: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md

## Notes

- The `<leader>s` prefix is registered as group "search" in which-key, so `<leader>st` reads as "search todos".
- `highlight.comments_only = true` means lines like `let x = "TODO"` are not highlighted — only real comments. If you ever see misses, check that treesitter parser is installed for the filetype.
- Snacks reads keywords + highlight groups from todo-comments' setup, so adding a custom keyword (e.g. `REVIEW`) automatically appears in the picker.
- Don't combine with `<leader>tt` — `t` prefix is "todo/test" (checkmate.nvim) which is for markdown todo-items, not comment keywords.
