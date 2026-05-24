# editor-checkmate
> Visual todo-list overlay for markdown — checkbox states, metadata, archiving.

**Repo:** https://github.com/bngarren/checkmate.nvim
**Local spec:** lua/plugins/editor.lua:415-480
**Tags:** todo, markdown, checkboxes, metadata, ui

## Scope

`checkmate.nvim` renders markdown task items (`- [ ]`, `- [x]`) as rich todos with Unicode icons, custom state cycles, metadata tags (`@priority(high)`, `@started(...)`, `@done(...)`), and an archive command that moves completed items to the bottom under `## Archive`. Owns checkbox rendering across all `*.md` buffers — for this reason [[editor-obsidian]] has `ui.enable = false` so the two plugins don't fight over extmarks.

## Install spec

```lua
{
  "bngarren/checkmate.nvim",
  ft = "markdown",
  opts = {
    keys = { ... },
    metadata = { priority = {...}, started = {...}, done = {...} },
  },
}
```

Loaded on `ft=markdown`. All keybinds are declared inside `opts.keys` (Checkmate's own loader) so they only attach in markdown buffers — not via lazy.nvim's `keys = {}`.

## Common customizations

- `files` *(string[], {"todo.md","TODO.md",...})* — glob patterns the plugin activates on. Default skips arbitrary `*.md` — we leave it default and rely on `ft = "markdown"` to ensure checkmate loads, then it gates itself per-file. To activate everywhere set `files = {"*.md"}`.
- `style` *(table)* — highlight groups for checked/unchecked/pending icons.
- `todo_markers` *(table, {unchecked="□",checked="✔"})* — glyphs rendered in place of `[ ]`/`[x]`.
- `default_list_marker` *(string, "-")* — bullet style for new todos.
- `enter_insert_after_new` *(bool, true)* — drop into insert mode after `Checkmate create`.
- `smart_toggle.enabled` *(bool, true)* — propagate checked-state up/down through nested children.
- `metadata.<name>` *(table)* — register a `@name(value)` tag with `style`, `get_value`, `choices`, `key`, `aliases`, `on_add`, `on_remove`, `sort_order`, `jump_to_on_insert`, `select_on_insert`.
- `archive.heading.title` *(string, "Archive")* — H2 used as the archive bucket.
- `linter.enabled` *(bool, true)* — warn about malformed todo lines.

WebFetch https://raw.githubusercontent.com/bngarren/checkmate.nvim/HEAD/README.md if uncertain.

## Our config

### Metadata tags

Three custom tags wire into the todo workflow:

- **`@priority(low|medium|high)`** — colour-coded (red/orange/cyan). Bound to `<leader>tp`. Defaults to `medium`, `select_on_insert = true` opens the choices picker.
- **`@started(timestamp)`** — auto-fills `mm/dd/yy HH:MM` on insert. Alias `@init`. Bound to `<leader>ts`.
- **`@done(timestamp)`** — auto-fills timestamp. Aliases `@completed`, `@finished`. Bound to `<leader>td`. Adding it auto-checks the todo (`on_add` calls `set_todo_state(..., "checked")`); removing it un-checks (`on_remove`).

The metadata `key` fields override Checkmate's own `<leader>T*` defaults — providing one entry replaces the default fully, so any field you want to keep must be copied (this is why each entry re-declares `style`, `get_value`, etc.).

### State cycling

`<leader>t=` cycles to the next state (`unchecked → checked → ...`), `<leader>t-` cycles backward. State list comes from `opts.todo_states` (default `unchecked`, `checked`); we don't extend it.

## Keymaps

All buffer-local to markdown. Registered via `opts.keys` (NOT lazy.nvim).

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tt` | n,v | `:Checkmate toggle` | Toggle todo item |
| `<leader>tc` | n,v | `:Checkmate check` | Check todo item |
| `<leader>tu` | n,v | `:Checkmate uncheck` | Uncheck todo item |
| `<leader>t=` | n,v | `:Checkmate cycle_next` | Cycle next state |
| `<leader>t-` | n,v | `:Checkmate cycle_previous` | Cycle previous state |
| `<leader>tn` | n,v | `:Checkmate create` | New todo item |
| `<leader>tx` | n,v | `:Checkmate remove` | Remove todo marker |
| `<leader>tR` | n,v | `:Checkmate remove_all_metadata` | Strip metadata from todo |
| `<leader>ta` | n | `:Checkmate archive` | Archive completed todos |
| `<leader>tf` | n | `:Checkmate select_todo` | Find todo (picker) |
| `<leader>tv` | n | `:Checkmate metadata select_value` | Set metadata value |
| `<leader>t]` | n | `:Checkmate metadata jump_next` | Next metadata tag |
| `<leader>t[` | n | `:Checkmate metadata jump_previous` | Prev metadata tag |
| `<leader>tp` | n,v | add `@priority` | Insert priority metadata |
| `<leader>ts` | n,v | add `@started` | Insert started timestamp |
| `<leader>td` | n,v | add `@done` | Insert done timestamp + check |

## Links

- Plugin repo: https://github.com/bngarren/checkmate.nvim
- Metadata schema: https://github.com/bngarren/checkmate.nvim#metadata

## Notes

- `<leader>t` is shared with neotest; [[editor-which-key]] labels it "todo/test". Checkmate bindings are buffer-local so they only show up in markdown.
- Coexists with [[editor-obsidian]] only because obsidian's `ui.enable = false`. If you re-enable obsidian UI, expect double-rendered checkboxes.
- The metadata `key` override quirk: declaring `metadata.priority = { key = "<leader>tp", ... }` discards Checkmate's default `style`/`choices`/`get_value`. We re-supply all of them.
- `Checkmate archive` moves done todos under an `## Archive` heading at the bottom of the file. Safe to run repeatedly.
