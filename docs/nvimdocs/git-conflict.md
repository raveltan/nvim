# git-conflict
> Highlight git merge-conflict markers and resolve them via the `<leader>gc` choose-ours/theirs/both/none group.

**Repo:** https://github.com/akinsho/git-conflict.nvim
**Local spec:** lua/plugins/git.lua:58
**Tags:** git, merge, conflict

## Scope
Detects `<<<<<<<`/`=======`/`>>>>>>>` blocks in any buffer, highlights the OURS/THEIRS sides, and provides keymaps to pick a side or jump between conflicts. Loaded on `BufReadPre` so highlights appear immediately when opening a conflicted file.

## Install spec
```lua
{
  "akinsho/git-conflict.nvim",
  version = "*",
  event = "BufReadPre",
  opts = { default_mappings = false },
  keys = {
    { "<leader>gco", "<cmd>GitConflictChooseOurs<cr>",   desc = "Choose ours" },
    { "<leader>gct", "<cmd>GitConflictChooseTheirs<cr>", desc = "Choose theirs" },
    { "<leader>gcb", "<cmd>GitConflictChooseBoth<cr>",   desc = "Choose both" },
    { "<leader>gc0", "<cmd>GitConflictChooseNone<cr>",   desc = "Choose none" },
    { "<leader>gcn", "<cmd>GitConflictNextConflict<cr>", desc = "Next conflict" },
    { "<leader>gcp", "<cmd>GitConflictPrevConflict<cr>", desc = "Prev conflict" },
    { "<leader>gcq", "<cmd>GitConflictListQf<cr>",       desc = "List conflicts (quickfix)" },
  },
}
```

## Common customizations
- `default_mappings` *(bool, true)* — enable the default `co/ct/cb/c0` and `]x/[x` mappings. We disable these in favour of `<leader>gc*` (which-key discoverable).
- `default_commands` *(bool, true)* — register `:GitConflict*` commands.
- `disable_diagnostics` *(bool, false)* — suppress LSP diagnostics inside conflict regions.
- `list_opener` *(string|fn, "copen")* — how `:GitConflictListQf` opens the quickfix list.
- `highlights.incoming` *(string, "DiffAdd")* — highlight group for THEIRS side.
- `highlights.current` *(string, "DiffText")* — highlight group for OURS side.

## Our config
- `default_mappings = false` — disable the plugin's `co/ct/cb/c0` + `]x/[x` mappings; they were awkward and hidden from which-key.
- All actions promoted to the `<leader>gc` (conflict) group via `:GitConflict*` commands, so which-key surfaces them.

## Keymaps
Our mappings (default plugin mappings disabled):

| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>gco` | n | choose ours | Keep OURS side |
| `<leader>gct` | n | choose theirs | Keep THEIRS side |
| `<leader>gcb` | n | choose both | Keep both sides |
| `<leader>gc0` | n | choose none | Delete the conflict block |
| `<leader>gcn` | n | next conflict | Jump to next conflict |
| `<leader>gcp` | n | prev conflict | Jump to previous conflict |
| `<leader>gcq` | n | list conflicts | Populate quickfix with all conflicts |

## Links
- README: https://github.com/akinsho/git-conflict.nvim/blob/main/README.md

## Notes
- For a side-by-side view of the conflicted file against the index, open `:Gdiffsplit` (fugitive); `:Gdiffsplit!` gives a 3-way OURS/THEIRS split during a merge.
- `:GitConflictListQf` populates the quickfix list with all conflicts in the repo.
- Plugin fires a `User GitConflictDetected` autocmd when a buffer has conflicts — useful for statusline integration if needed.
