# phab-inline.nvim

Shows Phabricator inline review comments inline in nvim buffers, for git
worktrees laid out as `.../D<revision-id>/...`.

## How it works

On `BufReadPost` / `BufEnter`, walks up from the buffer's path to find an
ancestor directory whose basename matches `D<digits>` (e.g.
`~/freelancer-dev/fl-gaf-worktree/D225194`). That directory name is the
Phabricator revision id, and the directory itself is treated as the repo
root for matching inline comment paths.

Comments are fetched once per session per revision per status via the bundled
`scripts/phab-inline-comments.sh <Dxxx> --status <status> --raw` (which talks
to Phabricator's Conduit API through the bundled `scripts/conduit.sh`),
parsed, and rendered as:

- gutter sign (`>>`) on each commented line
- end-of-line virtual text with author + first line
- virtual lines below the commented line with the full comment body

By default only comments not marked done (`incomplete`) are shown. You can
switch the active set to `done` or `all` via the commands / Lua API below
(see Showing done comments).

## Install (lazy.nvim)

```lua
{
  dir = "path/to/dir/phab-inline.nvim",
  name = "phab-inline.nvim",
  config = function()
    require("phab-inline").setup({
      keys = {
        open_all = "<leader>pi",
        refresh  = "<leader>pr",
        clear    = "<leader>pc",
        next     = "]p",
        prev     = "[p",
      },
    })
  end,
}
```

No keymaps are installed unless you ask for them. Note that `]p` and `[p`
shadow the built-in put-with-indent normal-mode mappings; omit those entries
if you want to keep them.

## Commands

- `:PhabInlineRefresh [incomplete|done|all]` - refetch for the current
  worktree. Status defaults to `incomplete`. The chosen status becomes the
  active set for the revision (subsequent renders / jumps use it).
- `:PhabInlineClear` - clear decorations in the current buffer
- `:PhabInlineOpenAll [incomplete|done|all]` - open every file in the current
  worktree that has inline comments of the given status (added to the buffer
  list; the first is shown). Status defaults to `incomplete`.
- `:PhabInlineToggle` - toggle visibility of inline comment decorations for
  the current worktree. The cache is kept; toggling back on redraws instantly
  without a network fetch.
- `:PhabInlineComments` - show non-inline (general) revision comments in a
  floating window (`q` or `<Esc>` to close). Use `:PhabInlineComments!` to
  bust the cache and refetch.
- `:PhabDescription` - show diff summary and test plan in a read-only float
  (`q` or `<Esc>` to close, `s` to edit summary, `t` to edit test plan). Use
  `:PhabDescription!` to bust the cache and refetch.
- `:PhabEditSummary` - open the diff summary in a Markdown scratch buffer.
  `:w` saves back to Phabricator via `differential.revision.edit`.
- `:PhabEditTestPlan` - open the diff test plan in a Markdown scratch buffer.
  `:w` saves back to Phabricator.
- `:PhabInlineNext` - jump to the next inline comment in the current buffer
  (wraps)
- `:PhabInlinePrev` - jump to the previous inline comment in the current
  buffer (wraps)

## Showing done comments

From the command line:

```
:PhabInlineRefresh done    " switch this rev's active set to done comments
:PhabInlineOpenAll done    " open every file that has a done comment
:PhabInlineRefresh all     " show both done and incomplete together
:PhabInlineRefresh         " back to default (incomplete)
```

Or from Lua:

```lua
require("phab-inline").refresh({ status = "done" })
require("phab-inline").open_all({ status = "all" })
```

The "active" status is tracked per revision, so `]p` / `[p` and auto-render
on `BufEnter` follow whatever you last asked for.

## Requirements

- `curl` and `jq` on `$PATH` (used by the bundled scripts).
- Phabricator credentials, either via env vars `PHABRICATOR_URL` and
  `PHABRICATOR_API_TOKEN`, or a `~/.arcrc` containing a host token.

## Configuration

```lua
require("phab-inline").setup({
  -- Defaults to the script bundled with this plugin. Override to point at
  -- a different phab-inline-comments.sh (conduit.sh is expected next to it).
  script = nil,
  virt_text_max = 100,
  auto = true,
  -- Script used to fetch non-inline revision comments (phab-comments.sh).
  -- Defaults to the bundled script; override if you need a custom version.
  comments_script = nil,
  -- No keymaps are installed by default. Pass a table to opt in. Recognised
  -- entries: open_all, refresh, clear, toggle, comments, description,
  -- edit_summary, edit_test_plan, next, prev. Omit (or set to false) any
  -- entry you do not want mapped.
  keys = false,
})
```

## Limitations

- Line numbers come from the diff snapshot. Local edits after the comment
  was posted will cause drift. Comments are clamped to the current buffer
  line count.
- Marking comments done or replying is not yet implemented.
- Summary/test plan edits overwrite the entire field. There is no merge with
  concurrent edits from other users.
