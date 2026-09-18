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
3. the `Differential Revision: <url>/D<id>` trailer of **HEAD itself** — the
   revision whose code the worktree is actually showing
4. an `arcpatch-D<id>` branch, which is what `arc patch` creates
5. the same trailer anywhere in the last 50 commits, for a tip that is a local
   fixup not yet amended into the revision commit

6. asking: a `vim.ui.input` prompt, once per worktree per session. An empty
   answer skips, and is remembered too (no nagging). Set
   `prompt_on_open = false` to only be asked from the commands themselves.

HEAD's trailer outranks the branch name because a patched stack keeps the
branch of the revision it started from: `arc patch D229985` on top of D229984
leaves the branch called `arcpatch-D229984` while HEAD is D229985's commit.
Targeting the branch there shows the parent's comments and refuses inline
comments on the child's files, since those files are not in the parent's diff.

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
| `<leader>pa` | draft an inline comment on this line (visual: on the selection) |
| `<leader>pe` | draft a suggested rewrite of this line / selection |
| `<leader>pE` | edit the draft on this line |
| `<leader>pX` | discard the draft on this line |
| `<leader>ps` | publish this session's drafts (asks for a cover message) |
| `<leader>pD` | picker: unpublished drafts |
| `]p` / `[p` | next / previous inline comment in the buffer (wraps) |

`]p`/`[p` shadow the builtin put-with-indent mappings; drop those entries in
`setup({ keys = ... })` to keep them.

## Commands

`:PhabRevision [Dxxx]` · `:PhabOpen [Dxxx]` · `:PhabRefresh [status] [Dxxx]` ·
`:PhabFiles [status] [Dxxx]` · `:PhabList [status] [Dxxx]` · `:PhabClear` ·
`:PhabToggle` · `:PhabNext` · `:PhabPrev` · `:PhabComments[!] [Dxxx]` ·
`:PhabDescription[!] [Dxxx]` · `:PhabEditSummary` · `:PhabEditTestPlan` ·
`:PhabComment[!]` (range) · `:PhabSuggest[!]` (range) · `:PhabSubmit` ·
`:PhabDrafts` · `:PhabDraftEdit` · `:PhabDraftDelete`

Arguments are order-free: a status word (`incomplete`/`done`/`all`) and/or a
revision (`D229985`, `229985`, or a Phabricator URL). `!` busts the cache and
refetches. A revision passed to a command becomes the worktree's revision.

## Writing inline comments

`:PhabComment` (`<leader>pa`, or a visual selection for a multi-line comment)
opens a **compose float** — a markdown scratch buffer named
`phab://D<id>/inline/<path>:<line>` in a `Snacks.win`. The buffer is `acwrite`,
so it works like any other buffer: **`:w` saves** (and `:wq`), **`:q` discards**
— no unsaved-changes complaint, a draft that was never written is meant to go.
`q` and `<Esc>` are there as quick discards. No key is bound in insert mode.

`compose = { save = "<cr>", discard = { "q", "<esc>" } }` binds an extra
normal-mode save key and replaces the quick-discard keys; each takes a key, a
list, or `false`. By default `save` is `false` — `:w` is the save.

Saving stores the comment as a **local draft**: nothing has reached Phabricator
yet. Drafts carry their own decoration — a `+>` sign and a `draft: …`
end-of-line preview in the `gaf_phab_draft` namespace — next to the fetched
comments, and can be rewritten or discarded freely:

| Action | How |
|---|---|
| edit the draft on this line | `<leader>pE` / `:PhabDraftEdit` |
| discard the draft on this line | `<leader>pX` / `:PhabDraftDelete` |
| browse every draft | `<leader>pD` / `:PhabDrafts` — `<CR>` edits, `<C-d>` discards, `<C-o>` jumps |

`:PhabSubmit` (`<leader>ps`) is the only step that writes: it pushes each draft
with `differential.createinline`, then publishes them with
`differential.createcomment` and `attach_inlines`, which is what turns pending
inlines into visible comments. If one `createinline` fails the run stops and
says how many are already pending, so the rest can be finished in the web UI.

**Publishing is verified, not trusted.** `differential.createcomment` reports
success for a call that applied nothing, so after it runs the revision is read
back with `transaction.search` and our own new transactions are counted:

| What came back | What happens |
|---|---|
| `inline` transactions | published; the local drafts are dropped |
| a `comment` but no inlines | the instance did not attach them — drafts kept, no second comment is posted |
| nothing at all | retried once through `differential.revision.edit`, then verified again |
| still nothing | drafts kept, with an error naming both endpoints |

Whenever the drafts are kept they are still sitting on the revision as
**unsubmitted inline comments** — open it in the browser and press Submit, and
they go out as they are.

Drafts are local to the session — closing Neovim drops them, and there is no
undo after publishing. That design is deliberate: Conduit exposes
`differential.createinline` and no method to edit or delete an inline comment,
so a comment that reached the server can only be changed from the web UI.
Keeping drafts in the editor is what makes editing and discarding possible at
all.

## Suggesting a code change

`:PhabSuggest` (`<leader>pe`, range-aware) opens the same float with the
commented lines already in a fenced block:

````
Prefer a guard clause here.

```lang=typescript
    if (a) {
      return 1;
    }
```
````

Rewrite what is inside the fence and save; the comment above it is optional.
Leaving the block untouched is refused rather than posting a no-op. The
language tag comes from the buffer's filetype.

`suggest_style` picks how the block is rendered:

- `"code"` (default) — the replacement alone, which is what reviewers on this
  instance already post by hand
- `"diff"` — `lang=diff` with the original lines as `-` and the rewrite as `+`

Phabricator has no structured suggestion field — `differential.createinline`
takes a `content` string and nothing else — so a suggestion is remarkup in the
comment body, not the "accept this change" widget GitHub has.

## Editing summary / test plan

Both open a scratch buffer named `phab://D<id>/<field>` with `buftype=acwrite`,
so `:w` runs `differential.revision.edit` instead of touching disk. The whole
field is overwritten — there is no merge with a concurrent edit by someone else.

## Requirements

`curl` and `jq` on `$PATH`, plus credentials: `PHABRICATOR_URL` +
`PHABRICATOR_API_TOKEN`, or a `~/.arcrc` with a host token. `:PhabOpen` uses
`config.url` (`$PHABRICATOR_URL`, else `https://phabricator.tools.flnltd.com`).

## Not implemented

Marking a comment done, replying to one, and editing or deleting a comment that
has already been published — Conduit has no method for any of them on this
instance (`conduit.query` lists only `differential.createinline` for inlines).
Published comments are changed from the web UI; `<leader>po` opens the
revision.
