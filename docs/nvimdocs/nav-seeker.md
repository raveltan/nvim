# seeker.nvim

Progressive file seeker built on the snacks.nvim picker. Start in a file picker, press `<C-e>` to grep within the filtered/selected files, press it again to reduce the file list to only files with matches — each switch refines the previous result without losing context.

Repo: https://github.com/2kabhishek/seeker.nvim

## Spec
Defined in [`lua/plugins/snacks.lua`](../../lua/plugins/snacks.lua), co-located with its `folke/snacks.nvim` dependency. Lazy-loaded on the `:Seeker` command / `<leader>/`.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>/` | n | `:Seeker` | Seek — auto-detect (git_files in a git repo, files otherwise) |
| `<C-e>` | picker (n/i) | toggle | Switch file ↔ grep mode (refines results) |
| `<Tab>` | picker (n/i) | select | Multi-select files to scope the next mode |

`<leader>/` replaced the old `Snacks.terminal.toggle()` binding — terminals are handled by tmux.

## Commands
- `:Seeker` — auto-detect (git_files in git repos, files otherwise)
- `:Seeker files` — all files
- `:Seeker git_files` — git-tracked files only
- `:Seeker grep` — start directly in grep
- `:Seeker grep_word` — grep the word under cursor

## Workflow
1. `<leader>/` opens the file picker.
2. Type to filter by name; optionally `<Tab>` to pick specific files.
3. `<C-e>` → grep within those files.
4. `<C-e>` again → file list narrows to files with matches.
5. Repeat to progressively narrow.

## Config
`opts = {}` (defaults). Toggle key is `<C-e>` (`toggle_key`); picker provider is `snacks`, matching our setup. See the repo README for `picker_opts` precedence.

## Links
- Repo: https://github.com/2kabhishek/seeker.nvim
- Related: [snacks-picker](snacks-picker.md), [nav-fff](nav-fff.md), [snacks-core](snacks-core.md)
