# snacks-dashboard
> Declarative startup dashboard — 2-pane layout with todo shortcut, recents, projects, and live git status.

**Repo:** https://github.com/folke/snacks.nvim
**Local spec:** lua/plugins/snacks.lua:3
**Tags:** snacks dashboard startup alpha-alternative

## Scope
`Snacks.dashboard` renders a declarative greeter on empty nvim startup. Sections are an ordered list; each entry either points to a built-in `section` (header, keys, recent_files, projects, startup, terminal) or supplies its own `text`/`action`/`key`. Our layout uses **two panes**: pane 1 holds the todo shortcut + cwd-scoped recents; pane 2 holds projects + global recents + a live `git status` terminal block. The header is an ASCII "RNVIM" banner.

## Install spec
```lua
dashboard = {
  enabled = true,
  sections = {
    { text = {
        { " █▀█ █▄░█ █░█ █ █▀▄▀█\n", hl = "SnacksDashboardHeader" },
        { " █▀▄ █░▀█ ▀▄▀ █ █░▀░█",   hl = "SnacksDashboardHeader" },
      }, padding = 1 },
    { pane = 1, icon = " ", desc = "Edit todo.md", key = "t",
      action = ":e ~/todo.md", padding = 1 },
    { pane = 1, icon = " ", title = "Recent Files (cwd)",
      section = "recent_files", cwd = true, limit = 5, indent = 2, padding = 1 },
    { pane = 2, icon = " ", title = "Projects",
      section = "projects", limit = 5, indent = 2, padding = 1 },
    { pane = 2, icon = " ", title = "Recent Files (all)",
      section = "recent_files", limit = 5, indent = 2, padding = 1 },
    { section = "startup" },
  },
},
```

## Common customizations
Top-level dashboard options (per `docs/dashboard.md`):

- `sections` *(table[])* — ordered list of section specs. Default includes header + keys + recents + projects + startup.
- `preset` *(table)* — picker integration target (`fzf-lua`, `telescope`, `mini.pick`, or `snacks.picker`) and session manager bindings; supplies the `action` for built-in `keys` entries.
- `width` *(int, 60)* — total dashboard width.
- `pane_gap` *(int, 4)* — horizontal gap between panes.
- `row` / `col` *(int|nil)* — manual placement, otherwise centered.

### Section spec fields
- `pane` *(int)* — vertical column (1, 2, …). Sections without `pane` span both.
- `section` *(string)* — built-in name: `header`, `keys`, `recent_files`, `projects`, `startup`, `terminal`.
- `text` *(string|table)* — raw content with optional `hl` highlight per chunk.
- `title` / `desc` *(string)* — section header / item label.
- `icon` *(string)* — leading glyph.
- `key` *(string)* — single-character keymap that triggers `action`.
- `action` *(string|function)* — `:cmd` string, `<keys>`, or lua function.
- `cwd` *(bool, false)* — for `recent_files`: restrict to current directory.
- `limit` *(int)* — max items in `recent_files`/`projects`/`keys`.
- `cmd` *(string)* — for `section = "terminal"`: shell command whose output is shown (colored, cached).
- `ttl` *(int)* — terminal section cache duration in seconds.
- `height` *(int)* — terminal section row count.
- `indent` *(int)* — left pad for items.
- `padding` *(int|{int,int})* — blank-line padding above/below.
- `enabled` *(bool|function)* — gate the section; here we hide Git Status outside a repo.

## Our config — section walkthrough
1. **Header** (full-width). Two-line block ASCII "RNVIM" in `SnacksDashboardHeader`.
2. **Edit todo.md** *(pane 1, key `t`)* — opens `~/todo.md` directly. Press `t` from the dashboard or click.
3. **Recent Files (cwd)** *(pane 1, limit 5)* — `recent_files` filtered to the directory you opened nvim in.
4. **Projects** *(pane 2, limit 5)* — uses the picker `projects` source (see [snacks-picker](snacks-picker.md)).
5. **Recent Files (all)** *(pane 2, limit 5)* — unfiltered MRU.
6. **Startup** — nvim load-time metrics (default footer).

No `preset` table is configured — we don't use the built-in `keys` section, so picker preset bindings are skipped.

## Keymaps
Dashboard keys are **declared inside sections** (the `key` field), not in lazy's `keys = {}`:

| Key | Mode | Action | Desc |
|---|---|---|---|
| `t` | n (dashboard buffer) | `:e ~/todo.md` | Open todo file |

Recent_files / projects sections handle Enter / mouse-click via their built-in actions — no manual key binding needed.

## Links
- README: https://github.com/folke/snacks.nvim
- Dashboard docs: https://github.com/folke/snacks.nvim/blob/main/docs/dashboard.md
- Related: [snacks-core](snacks-core.md), [snacks-picker](snacks-picker.md) (projects source), [snacks-misc](snacks-misc.md)

## Notes
- The `terminal` section type re-runs `cmd` only when its `ttl` expires — so `Git Status` is stale up to 5 min unless you `:e` the dashboard again.
- `enabled` on the Git Status section calls `Snacks.git.get_root()` at dashboard *render* time; opening nvim outside a repo skips the section entirely.
- Header uses `hl = "SnacksDashboardHeader"` — colorscheme provides the colour.
- The dashboard only shows when nvim opens with no file args and no piped stdin.
