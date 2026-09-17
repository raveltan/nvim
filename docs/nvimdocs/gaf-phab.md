# gaf-phab
> Phabricator inline review comments rendered in the buffer they were left on, plus the revision's general comments, summary and test plan — for worktrees laid out as `.../D<id>/...`

**Local module:** lua/gaf/phab/ (in-repo, not a plugin)
**Scripts:** scripts/phab/{conduit,phab-inline-comments,phab-comments}.sh
**Setup:** `require("gaf.phab").setup()` from lua/gaf/init.lua — GAF=1 only
**Tags:** phabricator, review, differential, conduit, arcanist, GAF

## Scope

Ported from the standalone `phab-inline.nvim` and rewired onto this config's
plugins: Snacks pickers instead of "open every commented file", Snacks.win
floats, the Snacks.toggle registry for visibility, and fidget for fetch
progress instead of a notification per call.

## Which revision am I reviewing?

Resolved per worktree, first hit wins:

1. an id set explicitly — `:PhabRevision D229985`, `<leader>pv`, or an id passed
   to any command (`:PhabFiles D229985 done`). Remembered for that worktree.
2. a `D<digits>` ancestor directory (`.../fl-gaf-worktree/D225194/...`) — that
   directory is also the root comment paths resolve against, and no git call is
   made
3. an `arcpatch-D<id>` branch, which is what `arc patch` creates
4. the `Differential Revision: <url>/D<id>` trailer of a recent commit — the
   last 50 are scanned, since the tip is often a local fixup that has not been
   amended into the revision commit yet
5. asking: a `vim.ui.input` prompt, once per worktree per session. An empty
   answer skips, and is remembered too (no nagging). Set
   `prompt_on_open = false` to only be asked from the commands themselves.

Outside (2), the worktree top level (`git rev-parse --show-toplevel`) is the
root comment paths resolve against, so an ordinary `fl-gaf` checkout works —
no special directory layout needed. `git` results are cached per directory and
per root, so the automatic path costs nothing after the first buffer.

Comments are fetched once per session per revision per status through
`scripts/phab/phab-inline-comments.sh`, which talks to Conduit via
`scripts/phab/conduit.sh`. Author PHIDs are resolved with `phid.query`; when
that call fails the PHID itself is shown rather than losing the comment.

## Decorations

One extmark per comment (namespace `gaf_phab_inline`), carrying all three
pieces, so clearing the namespace removes everything — no legacy sign group:

- gutter sign `>>` (`DiagnosticWarn`)
- end-of-line preview: author + first non-empty body line, truncated at
  `virt_text_max` (100)
- virtual lines below the line: the full body, gutter-barred

Line numbers come from the diff snapshot, so local edits after a comment was
posted drift; lines are clamped to the buffer's length.

## Status sets

`incomplete` (default), `done`, `all`. Each is cached separately per revision,
and the last one asked for becomes the revision's *active* set — `]p`/`[p`,
`BufEnter` rendering and the pickers all follow it.

## Keymaps

| Key | Action |
|---|---|
| `<leader>pi` | picker: files with inline comments (previewed at the first comment) |
| `<leader>pv` | set / ask for the revision this worktree reviews, then load it |
| `<leader>po` | open the revision in the browser |
| `<leader>pl` | picker: every inline comment (ivy layout) |
| `<leader>pr` | refetch the active status set |
| `<leader>pc` | clear decorations in this buffer |
| `<leader>pt` | toggle visibility (Snacks.toggle — cache kept, redraw is instant) |
| `<leader>pm` | general (non-inline) revision comments, float |
| `<leader>pd` | description float: summary + test plan (`s`/`t` to edit, `q`/`<Esc>` close) |
| `<leader>pS` | edit the diff summary |
| `<leader>pP` | edit the diff test plan |
| `]p` / `[p` | next / previous inline comment in the buffer (wraps) |

`]p`/`[p` shadow the builtin put-with-indent mappings; drop those entries in
`setup({ keys = ... })` to keep them.

## Commands

`:PhabRevision [Dxxx]` · `:PhabOpen [Dxxx]` · `:PhabRefresh [status] [Dxxx]` ·
`:PhabFiles [status] [Dxxx]` · `:PhabList [status] [Dxxx]` · `:PhabClear` ·
`:PhabToggle` · `:PhabNext` · `:PhabPrev` · `:PhabComments[!] [Dxxx]` ·
`:PhabDescription[!] [Dxxx]` · `:PhabEditSummary` · `:PhabEditTestPlan`

Arguments are order-free: a status word (`incomplete`/`done`/`all`) and/or a
revision (`D229985`, `229985`, or a Phabricator URL). `!` busts the cache and
refetches. A revision passed to a command becomes the worktree's revision.

## Editing summary / test plan

Both open a scratch buffer named `phab://D<id>/<field>` with `buftype=acwrite`,
so `:w` runs `differential.revision.edit` instead of touching disk. The whole
field is overwritten — there is no merge with a concurrent edit by someone else.

## Requirements

`curl` and `jq` on `$PATH`, plus credentials: `PHABRICATOR_URL` +
`PHABRICATOR_API_TOKEN`, or a `~/.arcrc` with a host token. `:PhabOpen` uses
`config.url` (`$PHABRICATOR_URL`, else `https://phabricator.tools.flnltd.com`).

## Not implemented

Marking a comment done, and replying. Both are read-only here today.
