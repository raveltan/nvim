# editor-obsidian
> Obsidian vault integration — daily notes, templates, backlinks, picker-driven search.

**Repo:** https://github.com/obsidian-nvim/obsidian.nvim
**Local spec:** lua/plugins/editor.lua:321-413
**Tags:** obsidian, notes, markdown, vault, templates

## Scope

`obsidian.nvim` (community fork; epwalsh's original repo is abandoned) treats a directory of markdown files as an Obsidian vault. It provides wiki-link navigation, backlinks, tag pickers, daily-note rotation, template insertion, image paste, and rename-with-link-refactor. We pair it with [[editor-checkmate]] for todos and [[util-obsidian]] for our title-prompt + slug + template-id helpers.

## Install spec

```lua
{
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  cmd = { "Obsidian" },
  opts = { ... },
  keys = { ... },
}
```

Loaded on `ft=markdown` or the `:Obsidian` command. Pinned to the latest semver tag (`version = "*"`).

## Common customizations

- `workspaces` *(table[])* — list of `{name, path}` vault roots. Switchable via `:Obsidian workspace`.
- `notes_subdir` *(string, nil)* — default folder for new notes inside the vault. We use `"inbox"`.
- `new_notes_location` *(string, "current_dir")* — `"current_dir"` | `"notes_subdir"`. We use `"notes_subdir"` so `:Obsidian new` lands in inbox.
- `daily_notes` *(table)* — `{folder, date_format, alias_format, default_tags, template}`. Date format is `strftime`.
- `templates.folder` / `templates.date_format` / `templates.time_format` *(string)* — template directory and `{{date}}`/`{{time}}` formats.
- `templates.substitutions` *(table<string,fun()>)* — custom `{{name}}` placeholders. We add `yesterday` and `tomorrow`.
- `ui.enable` *(bool, true)* — built-in concealing, checkbox glyphs, link rendering. We set `false` because [[editor-checkmate]] owns checkbox rendering.
- `completion.nvim_cmp` / `completion.blink` *(bool)* — completion engine bridges. We use `blink = true` (see [[cmp-blink]]).
- `completion.min_chars` *(integer, 2)* — chars typed before vault completion fires.
- `picker.name` *(string, "telescope.nvim")* — picker backend. We use `"snacks.pick"`.
- `wiki_link_func` *(string, "use_alias_only")* — how `[[link]]` text is rendered.
- `preferred_link_style` *(string, "wiki")* — `"wiki"` (`[[name]]`) or `"markdown"` (`[name](path)`).
- `disable_frontmatter` *(bool|fun(note))* — disable YAML frontmatter injection for some/all notes.
- `note_id_func` *(fun(title)->string)* — generate the filename slug. We slugify the title; fall back to timestamp if no title.
- `legacy_commands` *(bool, true)* — keep old `:ObsidianNew`-style commands. We set `false` to enforce the modern `:Obsidian new` namespace.

WebFetch https://raw.githubusercontent.com/obsidian-nvim/obsidian.nvim/HEAD/README.md if uncertain.

## Our config

- **Vault**: single workspace `personal` at `~/Documents/Obsidian`.
- **Inbox-first**: new notes default to `inbox/` (`notes_subdir = "inbox"`, `new_notes_location = "notes_subdir"`).
- **Daily notes** under `daily/`, filename `YYYY-MM-DD`, tagged `daily`, instantiated from `daily.md` template.
- **Templates** in `templates/`. Custom substitutions inject `{{yesterday}}` / `{{tomorrow}}` as YYYY-MM-DD.
- **UI off** (`ui.enable = false`) — checkmate.nvim handles checkbox glyphs; obsidian's link conceal also disabled to avoid extmark conflicts. Markdown rendering comes from `markview.nvim` instead.
- **Completion via blink** (`nvim_cmp = false`, `blink = true`) with 2-char minimum.
- **Picker = snacks.pick** for tags/backlinks/quick-switch.
- **Wiki links** with alias-only rendering and `[[wiki]]` syntax preferred.
- **Slug strategy**: lowercase, strip non-word/space/dash, collapse whitespace and dashes, trim leading/trailing dashes. Falls back to `os.date("%Y%m%d%H%M%S")` for untitled notes.

## Keymaps

All `<leader>n*` (group label "obsidian" via [[editor-which-key]]).

### Navigation / search
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>nf` | n | `:Obsidian quick_switch` | Find note (quick switch) |
| `<leader>ns` | n | `:Obsidian search` | Search vault content |
| `<leader>ng` | n | `:Obsidian tags` | Tags picker |
| `<leader>nb` | n | `:Obsidian backlinks` | Backlinks |
| `<leader>nl` | n | `:Obsidian links` | Links in note |
| `<leader>nF` | n | `:Obsidian follow_link` | Follow link |
| `<leader>no` | n | `:Obsidian open` | Open in Obsidian app |
| `<leader>nW` | n | `:Obsidian workspace` | Switch workspace |

### Daily / review
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>nd` | n | `:Obsidian today` | Today's daily |
| `<leader>ny` | n | `:Obsidian yesterday` | Yesterday's daily |
| `<leader>nT` | n | `:Obsidian tomorrow` | Tomorrow's daily |
| `<leader>nR` | n | `util.obsidian.weekly_review()` | Weekly review |

### Capture / from-template
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>nc` | n | `util.obsidian.capture("inbox")` | Capture to inbox |
| `<leader>nn` | n | `:Obsidian new` | New note (raw, inbox) |
| `<leader>np` | n | new_from_template projects/project | New project |
| `<leader>nm` | n | new_from_template meetings/meeting (date prefix) | New meeting |
| `<leader>nu` | n | new_from_template notes/bugs/bug | New bug |
| `<leader>nD` | n | new_from_template notes/decisions/decision (date prefix) | New decision (ADR) |
| `<leader>nk` | n | new_from_template notes/concepts/concept | New concept |
| `<leader>nP` | n | new_from_template people/person | New person |
| `<leader>nS` | n | new_from_template snippets/snippet | New snippet |
| `<leader>nB` | n | new_from_template notes/books/book | New book |

### Editing
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>ni` | n | `:Obsidian template` | Insert template at cursor |
| `<leader>nr` | n | `:Obsidian rename` | Rename note + refactor links |
| `<leader>nI` | n | `:Obsidian paste_img` | Paste image |
| `<leader>nL` | v | `:Obsidian link` | Link selection |
| `<leader>nX` | v | `:Obsidian extract_note` | Extract selection → note |
| `<leader>nt` | n | `:Obsidian toggle_checkbox` | Toggle checkbox |
| `<leader>nC` | n | `:Obsidian toc` | Table of contents |

## Links

- Plugin repo: https://github.com/obsidian-nvim/obsidian.nvim
- Original (archived): https://github.com/epwalsh/obsidian.nvim
- Our helpers: [[util-obsidian]]

## Notes

- `legacy_commands = false` is intentional — keeps the surface to one `:Obsidian` verb. If you find a tutorial that uses `:ObsidianNew`, mentally rewrite it as `:Obsidian new`.
- `note_id_func` is the slug for the filename, not the title; the title comes from the user prompt and is stored in frontmatter.
- The `<leader>n*` namespace is fully owned by Obsidian — don't add unrelated bindings under `n`.
- Most `<leader>n[uppercase]` keys are from-template creators that bounce through [[util-obsidian]] for title prompting; `<leader>n[lowercase]` are direct `:Obsidian` commands.
