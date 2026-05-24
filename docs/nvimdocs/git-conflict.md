# git-conflict
> Highlight git merge-conflict markers and resolve them with one-key choose-ours/theirs/both/none.

**Repo:** https://github.com/akinsho/git-conflict.nvim
**Local spec:** lua/plugins/git.lua:56-61
**Tags:** git, merge, conflict

## Scope
Detects `<<<<<<<`/`=======`/`>>>>>>>` blocks in any buffer, highlights the OURS/THEIRS sides, and provides keymaps to pick a side or jump between conflicts. Loaded on `BufReadPre` so highlights appear immediately when opening a conflicted file.

## Install spec
```lua
{
  "akinsho/git-conflict.nvim",
  version = "*",
  event = "BufReadPre",
  config = true,
}
```

## Common customizations
- `default_mappings` *(bool, true)* — enable the default `co/ct/cb/c0` and `]x/[x` mappings.
- `default_commands` *(bool, true)* — register `:GitConflict*` commands.
- `disable_diagnostics` *(bool, false)* — suppress LSP diagnostics inside conflict regions.
- `list_opener` *(string|fn, "copen")* — how `:GitConflictListQf` opens the quickfix list.
- `highlights.incoming` *(string, "DiffAdd")* — highlight group for THEIRS side.
- `highlights.current` *(string, "DiffText")* — highlight group for OURS side.

## Our config
- `config = true` — use upstream defaults verbatim (default mappings on, default highlight groups).

## Keymaps
Default mappings from the plugin (we don't override):

| Key | Mode | Action | Desc |
|---|---|---|---|
| `co` | n | choose ours | Keep OURS side |
| `ct` | n | choose theirs | Keep THEIRS side |
| `cb` | n | choose both | Keep both sides |
| `c0` | n | choose none | Delete the conflict block |
| `]x` | n | next conflict | Jump to next conflict |
| `[x` | n | prev conflict | Jump to previous conflict |

## Links
- README: https://github.com/akinsho/git-conflict.nvim/blob/main/README.md

## Notes
- For a side-by-side 3-way view of the same conflict, open `:DiffviewOpen` (diffview is configured with `merge_tool.layout = "diff3_mixed"`).
- `:GitConflictListQf` populates the quickfix list with all conflicts in the repo.
- Plugin fires a `User GitConflictDetected` autocmd when a buffer has conflicts — useful for statusline integration if needed.
