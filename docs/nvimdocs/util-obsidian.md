# util-obsidian
> Helpers that prompt for a title, slugify it, and dispatch `:Obsidian new_from_template`.

**Local spec:** lua/util/obsidian.lua:1-51
**Tags:** util, obsidian, templates, slugify, module

## Scope

A thin wrapper around `:Obsidian new_from_template` (see [[editor-obsidian]]) that:

1. Prompts the user for a title via `vim.ui.input`.
2. Slugifies it (lowercase, strip punctuation, collapse whitespace and dashes).
3. Optionally prefixes the slug with today's date.
4. Builds an id of the form `<folder>/<slug>` and runs the Obsidian command with the chosen template.

The `<leader>n*` keymap family in [[editor-obsidian]] delegates to these three functions for every "new X from template" binding.

## Install spec

```lua
-- not a plugin; require directly:
local obsidian = require("util.obsidian")
```

Pure Lua module, no dependencies beyond `:Obsidian new_from_template` being installed (i.e., [[editor-obsidian]] active).

## Public API

### `M.new_from_template(opts)`

Prompts for a title, slugifies, and runs `:Obsidian new_from_template <folder>/<slug> <template>`.

- `opts.folder` *(string, required)* — vault-relative folder for the new note (e.g., `"projects"`, `"notes/bugs"`).
- `opts.template` *(string, required)* — template name (without `.md`) inside `templates/`.
- `opts.prompt` *(string, default `"Title: "`)* — text shown by `vim.ui.input`.
- `opts.date_prefix` *(bool, default false)* — if true, slug becomes `YYYY-MM-DD-<slug>`. Used for meetings and decisions where the date matters more than the title.

Returns nothing. Aborts silently if the user submits empty input.

Example: `obsidian.new_from_template({ folder = "projects", template = "project", prompt = "Project name: " })`.

### `M.capture(folder)`

Fast inbox-style capture. Prompts for a title, then runs `:Obsidian new_from_template <folder>/<YYYY-MM-DD-HHMM>-<slug> inbox`. The slug always carries a date+time prefix so captures sort chronologically and never collide. Template is hard-coded to `inbox`.

- `folder` *(string, required)* — destination folder, typically `"inbox"`.

Bound to `<leader>nc` (Capture to inbox).

### `M.weekly_review()`

Creates `notes/reviews/<YYYY>-W<WW>` from the `weekly` template. No prompt — the year+ISO-week tuple is the title. Idempotent within a week (Obsidian will open the existing note if it's already there).

Bound to `<leader>nR` (Weekly review).

## Internal helpers (not exported)

- `slugify(s)` — local function. Lowercase, strip non-word/space/dash, collapse whitespace to single dash, collapse runs of dashes, trim leading/trailing dashes. Identical algorithm to `note_id_func` in [[editor-obsidian]] so generated filenames stay consistent.

## Our config

The whole module **is** the config. No options.

## Keymaps

This module exposes no keymaps directly. Callers (the [[editor-obsidian]] spec) register `<leader>n*` bindings that invoke these functions:

| Key | Function | Folder | Template |
|-----|----------|--------|----------|
| `<leader>nc` | capture | `inbox` | `inbox` |
| `<leader>nR` | weekly_review | `notes/reviews` | `weekly` |
| `<leader>np` | new_from_template | `projects` | `project` |
| `<leader>nm` | new_from_template (date prefix) | `meetings` | `meeting` |
| `<leader>nu` | new_from_template | `notes/bugs` | `bug` |
| `<leader>nD` | new_from_template (date prefix) | `notes/decisions` | `decision` |
| `<leader>nk` | new_from_template | `notes/concepts` | `concept` |
| `<leader>nP` | new_from_template | `people` | `person` |
| `<leader>nS` | new_from_template | `snippets` | `snippet` |
| `<leader>nB` | new_from_template | `notes/books` | `book` |

## Links

- Parent plugin spec: [[editor-obsidian]]
- Obsidian command reference: https://github.com/obsidian-nvim/obsidian.nvim/blob/HEAD/doc/obsidian-commands.txt

## Notes

- Empty-input abort is intentional — pressing `<Esc>` at the prompt should silently bail, not surface an error.
- `vim.ui.input` callback is async; the `:Obsidian` command runs after the user submits, not when the function returns. Don't chain logic after the call.
- The `weekly_review` ISO week uses `%V` (POSIX ISO 8601 week), not `%W` (US Monday-start). Verified on macOS BSD date — works there too.
- Slug collisions: if two captures happen in the same minute the filename collides; `:Obsidian new_from_template` will open the existing note rather than overwrite.
