# Obsidian — Note-taking Guide

Comprehensive guide for using `obsidian.nvim` inside this config. Covers vault layout, every template, the full `<leader>n*` keymap surface, capture/triage/review workflows, and integration with checkmate, markview, blink, and Obsidian.app.

> Plugin spec: [`docs/nvimdocs/editor-obsidian.md`](nvimdocs/editor-obsidian.md) · helpers: [`docs/nvimdocs/util-obsidian.md`](nvimdocs/util-obsidian.md) · keymap row: [`docs/keybinds.md`](keybinds.md) §Obsidian.

---

## 1. What you get

- **Vault** at `~/Documents/Obsidian` (single workspace `personal`).
- **`[[wiki-link]]` navigation** with backlink discovery, link refactor on rename, link picker.
- **Daily / weekly notes** with `{{date}}`, `{{yesterday}}`, `{{tomorrow}}` template substitutions.
- **Typed templates** for projects, meetings, decisions (ADRs), bugs, concepts, people, books, snippets, captures.
- **Title-prompt creators** (`util.obsidian`) — you type a title, it slugifies + scaffolds the right folder/template.
- **Picker-driven search** via `snacks.pick` (quick-switch, tags, backlinks, links-in-note).
- **Image paste**, **TOC**, **checkbox toggle**, **extract selection → new note**.
- **Open-in-app** bridge (`<leader>no`) for graph view / canvas / mobile sync.

UI rendering split:

| Concern | Owner |
|---------|-------|
| Checkbox glyphs / cycle | [checkmate.nvim](nvimdocs/editor-checkmate.md) |
| Markdown render (headings, code, tables) | [markview.nvim](nvimdocs/markview.md) |
| Wiki-link completion (`[[` + 2 chars) | [blink.cmp](nvimdocs/cmp-blink.md) via obsidian bridge |
| Image inline preview | [snacks image](nvimdocs/snacks-misc.md) |

`obsidian.nvim`'s own `ui` is **disabled** (`ui.enable = false`) — checkmate owns checkbox extmarks; markview owns the rest.

---

## 2. Vault layout

```
~/Documents/Obsidian/
├── daily/                   YYYY-MM-DD.md daily notes
├── inbox/                   capture dump — must be triaged
├── projects/                long-running work, one note per project
├── meetings/                YYYY-MM-DD-<slug>.md per meeting
├── people/                  1:1 notes, teammates
├── snippets/                personal code/CLI snippets (prose, not LuaSnip)
├── notes/
│   ├── bugs/                bug write-ups
│   ├── decisions/           ADRs (YYYY-MM-DD-<slug>.md)
│   ├── concepts/            knowledge atoms — one idea per note
│   ├── books/               book notes
│   └── reviews/             YYYY-W##.md weekly reviews
└── templates/               *.md template sources (do not edit unless updating shape)
```

**Defaults** (`lua/plugins/editor.lua`):

- New notes (`<leader>nn`) land in `inbox/` (`notes_subdir = "inbox"`, `new_notes_location = "notes_subdir"`).
- Captures (`<leader>nc`) prefix the slug with `YYYY-MM-DD-HHMM` so they sort chronologically.
- Filenames are slugified from the prompt — lowercase, dashes for spaces, punctuation stripped. Title lives in frontmatter, not the filename.

---

## 3. The `<leader>n*` keymap surface

Group label `obsidian` (which-key). Lowercase = direct `:Obsidian` verb. Uppercase = from-template creator that runs through `util.obsidian` for title prompting.

### Navigation / search

| Key | Action |
|-----|--------|
| `<leader>nf` | Quick switch (fuzzy filename + alias) |
| `<leader>ns` | Search vault content (live grep) |
| `<leader>ng` | Tags picker — pick a tag to list its notes |
| `<leader>nb` | Backlinks for current note |
| `<leader>nl` | All `[[links]]` in current note |
| `<leader>nF` | Follow link under cursor |
| `<leader>no` | Open current note in Obsidian.app |
| `<leader>nW` | Switch workspace (only one configured today) |

### Daily / review

| Key | Action |
|-----|--------|
| `<leader>nd` | Today's daily note (creates if missing) |
| `<leader>ny` | Yesterday's daily |
| `<leader>nT` | Tomorrow's daily (for planning) |
| `<leader>nR` | Weekly review (`notes/reviews/YYYY-W##.md`) |

### Capture / new-from-template

| Key | Folder | Template | Date prefix |
|-----|--------|----------|-------------|
| `<leader>nc` | `inbox/` | `inbox` | `YYYY-MM-DD-HHMM` (auto) |
| `<leader>nn` | `inbox/` | (raw `:Obsidian new`) | no |
| `<leader>np` | `projects/` | `project` | no |
| `<leader>nm` | `meetings/` | `meeting` | `YYYY-MM-DD` |
| `<leader>nu` | `notes/bugs/` | `bug` | no |
| `<leader>nD` | `notes/decisions/` | `decision` | `YYYY-MM-DD` |
| `<leader>nk` | `notes/concepts/` | `concept` | no |
| `<leader>nP` | `people/` | `person` | no |
| `<leader>nS` | `snippets/` | `snippet` | no |
| `<leader>nB` | `notes/books/` | `book` | no |

### Editing inside a note

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ni` | n | Insert template at cursor (pick from `templates/`) |
| `<leader>nr` | n | Rename note + refactor all `[[links]]` to it |
| `<leader>nI` | n | Paste clipboard image (saves to vault, inserts `![[image.png]]`) |
| `<leader>nL` | v | Wrap selection as `[[link]]` (prompts for target) |
| `<leader>nX` | v | Extract selection → new note + replace with link |
| `<leader>nt` | n | Toggle checkbox state under cursor |
| `<leader>nC` | n | Table of contents picker (jump to heading) |

`<leader>nt` only works on Obsidian-native `- [ ]`. For richer cycle (`[ ] → [.] → [x] → [/]`), use checkmate's `<leader>Tt` / `<leader>Tx` instead — see [editor-checkmate](nvimdocs/editor-checkmate.md).

---

## 4. Templates — what each one is for

All under `~/Documents/Obsidian/templates/`. Substitutions: `{{id}}`, `{{title}}`, `{{date:FMT}}`, `{{time:FMT}}`, `{{yesterday}}`, `{{tomorrow}}`.

### `daily.md` — `<leader>nd`
Today's running log. Three-bullet Focus, freeform Log + Notes, Carry-to-tomorrow checkboxes, prev/next daily wiki-links. Open it first thing.

### `weekly.md` — `<leader>nR`
ISO-week review. Shipped / Carried / Inbox triage / Active projects table / Retro / Next-week top-3. Run **Friday afternoon or Monday morning**, not both. Idempotent within a week.

### `inbox.md` — `<leader>nc` and `<leader>nn`
Capture-fast. Just frontmatter + `# {{title}}`. Body is whatever you dump. Triage during the weekly review — promote to a typed template, archive, or delete.

### `project.md` — `<leader>np`
One note per multi-week project. Frontmatter has `status`, `repo`, `ticket`, `branch`, `stakeholders`. Body: Goal / Context / Approach / Open questions / Todo / Decisions / Blockers / Links / dated Log. **The project note is the canonical hub** — link meetings, decisions, and bugs back into it.

### `meeting.md` — `<leader>nm`
Filename prefixed `YYYY-MM-DD-`. Tracks attendees, agenda, notes, decisions, action items (`- [ ] @me — ...`), follow-ups. Run `<leader>nb` from a project note to see all meetings linked to it.

### `decision.md` — `<leader>nD`
Architecture Decision Record. Filename prefixed `YYYY-MM-DD-`. Status flows `proposed → accepted → superseded → deprecated`. Body forces Context / Options / Decision / Consequences / Revisit-when. Link superseding ADRs both ways.

### `bug.md` — `<leader>nu`
Postmortem-style. Symptom / Repro / Root cause / Fix / Why-it-happened / Prevention. Link to commit + stacktrace + ticket. Useful even for "fixed in 5 minutes" bugs — pattern emerges over months.

### `concept.md` — `<leader>nk`
Single-idea atomic note. TL;DR / Definition / How-it-works / When-to / When-not-to / Examples / Gotchas / Sources. Optimize for **future re-reading**, not first-write effort. Link liberally with `[[other-concept]]`.

### `person.md` — `<leader>nP`
One per teammate. Role / team / TZ / contact / preferences / strengths / working-style. Append to **1:1 log** after every chat (insert new `### YYYY-MM-DD` heading).

### `snippet.md` — `<leader>nS`
Prose snippet — a CLI invocation, a tricky regex, a deployment recipe. Has What / When-to-use / Code / Example / Caveats. **Not** the same as `nvim-scissors` LuaSnip JSON in `~/.config/nvim/snippets/` (those are editor expansions, see §8).

### `book.md` — `<leader>nB`
Book log. Author / status / rating / started / finished frontmatter; TL;DR / Why-read / Key-ideas / Quotes / Actions-I'll-take. Keep it short — overwriting is allowed.

---

## 5. Workflows

### 5.1 Daily routine

1. `<leader>nd` — open today's daily.
2. Fill **Focus (3 max)** before anything else. Yesterday's `Carry to tomorrow` is at `<leader>ny → copy → paste`.
3. During the day, anything not-Focus goes to `<leader>nc` (capture). Don't break flow to organize.
4. End of day: skim inbox, drag actionable items into the daily `Log`, fill `Carry to tomorrow`.

### 5.2 Inbox → triage

Captures pile up in `inbox/`. Process during the **weekly review**:

| Capture type | Action |
|--------------|--------|
| Half-formed idea worth keeping | `<leader>nk` → new concept note, link from inbox note, delete inbox note |
| Bug observation | `<leader>nu` → bug note |
| Decision to make | `<leader>nD` → ADR |
| Already done / no value | Delete |
| Belongs in a project | Cut content, paste into project's Log section, delete inbox note |

Use `<leader>nX` (visual select → extract) to split a long inbox dump into multiple typed notes in one motion.

### 5.3 Weekly review

`<leader>nR` opens `notes/reviews/YYYY-W##.md`:

1. **Shipped** — scrape `git log --since="7 days ago" --author=$(git config user.email)`.
2. **Carried over** — pull from last week's note (linked via `<leader>nb` after first review).
3. **Inbox triage** — apply table above. Goal: inbox empty.
4. **Active projects** — open each `projects/*.md`, update status + next-step.
5. **Retro** — what worked / what didn't.
6. **Top 3 next week** — these become focus targets for next week's dailies.

### 5.4 Project lifecycle

```
<leader>np                  → create projects/foo.md from template
<leader>nm during meetings  → meetings/YYYY-MM-DD-foo-kickoff.md
                              add `[[foo]]` in body → backlink appears automatically
<leader>nD when stuck       → notes/decisions/YYYY-MM-DD-foo-storage.md
<leader>nu when bug found   → notes/bugs/foo-cache-leak.md
<leader>nb inside foo.md    → see all meetings/decisions/bugs linked back
status: active → done       → edit frontmatter, run `<leader>ng` "status/done" to list archived projects
```

### 5.5 Concept building (Zettelkasten-lite)

Atomic concept notes are the long-term value of the vault.

- **One idea per note.** If you find yourself adding `## Another thing`, split with `<leader>nX`.
- **Link before you write.** Open `<leader>nk`, before drafting the body do `<leader>nf` and link to 2–3 related concepts. Forces your brain to position the idea.
- **Aliases** in frontmatter help discovery: `aliases: [TCC, transitive closure]`.
- **No hierarchy.** Don't make `concepts/database/`, `concepts/network/`. Flat folder + tags. Find via `<leader>nf` or `<leader>ng`.

### 5.6 Linking patterns

| You want… | Do |
|-----------|-----|
| Quick reference to another note | Type `[[`, blink completes after 2 chars |
| Link with custom display text | `[[target\|display text]]` |
| Embed another note (transclude) | `![[target]]` |
| Embed image you just screenshotted | `<leader>nI` (paste from clipboard) |
| Turn current selection into a link | visual select → `<leader>nL` |
| Split a section into its own note | visual select → `<leader>nX` |
| See who links to current note | `<leader>nb` |
| See all links going out of current note | `<leader>nl` |
| Renaming note + fix every backlink | `<leader>nr` (never `:Move` or shell `mv`) |

---

## 6. Frontmatter conventions

Every note has YAML frontmatter inserted by the template. Useful tag conventions for search:

- `tags: [project, status/active]` → list with `<leader>ng` → pick `status/active`.
- `tags: [bug, severity/high]` → triage high-sev with one tag pick.
- `tags: [meeting, project/foo]` → group meetings by project even before linking.
- `aliases: [...]` → quick-switch matches alias text, not just filename.

Hierarchical tags (`status/active`) are flat strings to Obsidian but render as a tree in the tags picker.

---

## 7. Search / discovery

| Tool | Use when |
|------|----------|
| `<leader>nf` quick switch | You roughly know the title or alias |
| `<leader>ns` content search | You remember a phrase from inside the note |
| `<leader>ng` tags | You want a category (e.g. all open bugs) |
| `<leader>nb` backlinks | You're on a hub note (project/person) and want orbiting notes |
| `<leader>nl` links | You're on a note and want to walk outward |
| `<leader>nC` TOC | Long note (weekly review, big project) — jump by heading |
| `:NvimDocs` | You want to read config docs, not vault notes |

---

## 8. Snippets — two different things

| Kind | Stored in | Tool | Trigger |
|------|-----------|------|---------|
| **Editor snippets** (LuaSnip) | `~/.config/nvim/snippets/*.json` | `nvim-scissors` | Type prefix → `<Tab>` expand |
| **Prose snippets** (vault) | `~/Documents/Obsidian/snippets/*.md` | `obsidian.nvim` | `<leader>nS` create, `<leader>nf` find |

Use editor snippets for code you type often (controllers, components, RSpec scaffolds). Use vault snippets for human-readable recipes (deploy command, regex with explanation, CLI one-liner you'll forget).

Edit / add editor snippets from inside Neovim:

| Key | Action |
|-----|--------|
| `<leader>Se` | Edit existing snippet (scissors popup) |
| `<leader>Sa` | Add new snippet for current filetype |

See [snippets-dir](nvimdocs/snippets-dir.md) for the JSON shape and [editor-scissors](nvimdocs/editor-scissors.md) for the editor.

---

## 9. Image paste

1. Screenshot into clipboard (macOS: `Cmd-Shift-Ctrl-4`).
2. In note, `<leader>nI`.
3. Prompt asks for a name → file written to vault's image dir → `![[name.png]]` inserted.
4. Inline preview via snacks image (in terminals that support kitty graphics / sixel).

Open in Obsidian.app (`<leader>no`) to see images in the graph view or on mobile.

---

## 10. Working with Obsidian.app

The vault is **shared** with the Obsidian desktop/mobile app. Both edit the same `.md` files.

- **`<leader>no`** opens the current Neovim buffer in Obsidian.app via the `obsidian://` URL scheme.
- Sync (iCloud / Obsidian Sync / Git) handled by the app, not by nvim — nvim only reads/writes files.
- **Conflict avoidance**: don't leave the same note open in both at once. If you do, save in one and `:e!` in the other.
- Canvas files (`.canvas`) and graph view live only in the app. Daily/template/wiki-link flow works identically in both.

---

## 11. Customizing

| Want to… | Where |
|----------|-------|
| Add a new template | Drop `templates/foo.md` + add `<leader>nX` keymap in `lua/plugins/editor.lua` |
| Change daily note format | `opts.daily_notes` in `lua/plugins/editor.lua:331-337` |
| Change slug rules | `slugify` in `lua/util/obsidian.lua:7-14` (mirror in `note_id_func`) |
| Add a substitution | `opts.templates.substitutions` in `lua/plugins/editor.lua:342-349` |
| Add a second workspace | `opts.workspaces` then `<leader>nW` to switch |
| Make completion fire sooner | `opts.completion.min_chars` (default 2) |

Plugin spec lives at `lua/plugins/editor.lua:317-412`. Helpers at `lua/util/obsidian.lua`.

---

## 12. Troubleshooting

- **Checkboxes look wrong / duplicated glyphs** — checkmate vs obsidian extmark fight. Verify `ui.enable = false` in editor.lua.
- **`[[` completion not firing** — ensure file is markdown (`ft=markdown`), wait 2 chars, check blink isn't deferred. See [cmp-blink](nvimdocs/cmp-blink.md).
- **`:Obsidian new` lands in wrong folder** — `notes_subdir` is `"inbox"`; change there, not at call site.
- **Daily missing `{{yesterday}}` link** — substitution defined in `opts.templates.substitutions`; if you copy a template ensure the curly form is `{{yesterday}}` not `{{ yesterday }}`.
- **Rename broke a backlink** — only `<leader>nr` (`:Obsidian rename`) is link-safe; `mv` / `:Move` / Oil rename are not.
- **`legacy_commands = false` means `:ObsidianNew` errors** — use `:Obsidian new` (single verb). Plugin's old syntax is intentionally disabled.

---

## 13. Quick reference card

```
DAILY      nd today    ny yest    nT tom     nR weekly
NAV        nf switch   ns search  ng tags    nb backlinks   nl links   nF follow
CREATE     nc capture  nn raw     np project nm meeting     nD decision
           nu bug      nk concept nP person  nS snippet     nB book
EDIT       ni insert   nr rename  nI image   nL link(v)     nX extract(v)
           nt checkbox nC toc     no app     nW workspace
SNIPPETS   Se edit     Sa add        (editor snippets, not vault)
```
