# config-keymaps
> Global keymaps: windows, buffers, LSP, diagnostics, case conversion, search centering, quickfix.

**Local file:** lua/config/keymaps.lua
**Tags:** config, keymaps, lsp, diagnostics, abolish, gaf

## Scope

`lua/config/keymaps.lua` defines every leader-prefixed and free-key global mapping. Plugin-owned maps (e.g. `<leader>ca` from `actions-preview.nvim`, telescope/snacks pickers) live with the plugin spec. Filetype-local maps live in `after/ftplugin/`.

## Highlights

- A custom **resize submode** (`<leader>wr`) consumes single keys via `vim.fn.getcharstr` so you can hammer `hjkl` (and `HJKL` for x5 steps) without re-pressing the leader.
- `<leader>cr` is a hand-rolled LSP rename that compensates for intelephense's `$` sigil bug — when the cursor sits on `$`, it advances one column, strips/re-prepends the sigil around the user input, and applies the workspace edit manually with `client:request`. See memory `nvim_php_rename.md`.
- `gx` first delegates to GAF's `open_phab_under_cursor` (D-numbers, T-numbers, paste IDs) when `vim.g.gaf` is set, then falls back to `vim.ui.open` for normal URLs / `<cfile>`.
- Search-result motions `n`/`N` recenter (`zzzv`) and trigger `hlslens.start()` so the lens annotations refresh.

## Keymaps

### Window splits & resize
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>\|` | n | `:vsplit` | Vertical split |
| `<leader>-` | n | `:split` | Horizontal split |
| `<C-Up>` | n | `:resize +2` | Increase height |
| `<C-Down>` | n | `:resize -2` | Decrease height |
| `<C-Left>` | n | `:vertical resize -2` | Decrease width |
| `<C-Right>` | n | `:vertical resize +2` | Increase width |
| `<leader>wr` | n | resize submode | Loop on `hjkl`/`HJKL`/`=` |

### Move lines
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<A-j>` / `<A-k>` | n | `:m` + `==` | Move line down/up |
| `<A-j>` / `<A-k>` | v | `:m` + `gv=gv` | Move selection down/up |

### Save / Quit / Buffers
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<C-s>` | n,i,x,s | `:w` + `<esc>` | Save file |
| `<leader>qq` | n | `:qa` | Quit all |
| `<S-h>` / `<S-l>` | n | `:bprevious` / `:bnext` | Prev/next buffer |
| `<leader>bo` | n | `%bd\|e#\|bd#` | Close other buffers |
| `<leader>fn` | n | `:enew` | New file |

### Search / highlights / centering
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<esc>` | n | `:noh` | Clear search highlights |
| `<C-d>` / `<C-u>` | n | `15jzz` / `15kzz` | Small jump down/up centered |
| `n` / `N` | n | `…zzzv` + hlslens | Next/prev result centered |
| `J` | n | `mzJ\`z` | Join without moving cursor |
| `gw` | n | `Snacks.picker.grep` | Grep word under cursor |
| `gx` | n | GAF Phab/`vim.ui.open` | Open URL/file under cursor |

### LSP
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `K` | n | `vim.lsp.buf.hover` | Hover docs |
| `<leader>cA` | n | source code action | Source action |
| `<leader>cr` | n | sigil-aware rename | Rename symbol |
| `<leader>cf` | n | `conform.format` | Format file |
| `<leader>ci` | n | toggle inlay hints | Toggle inlay hints |

(`<leader>ca` for regular code actions is owned by `actions-preview.nvim`.)

### Diagnostics
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>cd` | n | `vim.diagnostic.open_float` | Line diagnostics |
| `[d` / `]d` | n | `vim.diagnostic.jump` | Prev/next diagnostic |
| `[e` / `]e` | n | jump ERROR | Prev/next error |
| `[w` / `]w` | n | jump WARN | Prev/next warning |
| `<leader>ud` | n | toggle diagnostics | Toggle diagnostics |
| `<leader>uf` | n | flip `g:disable_autoformat` | Toggle format-on-save |

### Case conversion (vim-abolish)
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>cvs` | n | `crsiw` | snake_case |
| `<leader>cvc` | n | `crciw` | camelCase |
| `<leader>cvp` | n | `crmiw` | PascalCase |
| `<leader>cvu` | n | `cruiw` | UPPER_CASE |
| `<leader>cvk` | n | `cr-iw` | kebab-case |
| `<leader>cvd` | n | `cr.iw` | dot.case |
| `<leader>cvt` | n | `crtiw` | Title Case |

### Visual helpers
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<` / `>` | v | `<gv` / `>gv` | Reselect after indent |
| `<leader>p` | x | `"_dP` | Paste without overwrite |

### Terminal
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<esc><esc>` | t | `<C-\><C-n>` | Exit terminal mode |

(Single `<Esc>` deliberately passes through to TUI apps like `lazygit`.)

### Quickfix / loclist
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>xq` | n | toggle qf | Toggle quickfix |
| `<leader>xl` | n | toggle ll | Toggle loclist |

## Links

- Related [config-init](config-init.md)
- Related [config-autocmds](config-autocmds.md)
- LSP rename context: [ftplugin-php](ftplugin-php.md), memory `nvim_php_rename.md`
- GAF `gx` hook: `lua/gaf/keymaps.lua` (`open_phab_under_cursor`)
- Plugins referenced: `hlslens`, `Snacks.picker`, `conform.nvim`, `vim-abolish`, `actions-preview.nvim`

## Notes

- `<leader>cr` only fires when at least one attached client supports `textDocument/rename`; otherwise it warns and bails.
- After a successful rename it runs `silent! wall` so the edit is written to disk immediately.
- `<leader>uf` flips a global, not a buffer-local — `conform.format_after_save` reads `vim.g.disable_autoformat`.
- The resize submode redraws and prints a hint line; press `q` or `<Esc>` (or any non-listed key) to leave.
