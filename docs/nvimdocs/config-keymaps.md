# config-keymaps
> Global keymaps: windows, buffers, LSP, diagnostics, case conversion, search centering, loclist.

**Local file:** lua/config/keymaps.lua
**Tags:** config, keymaps, lsp, diagnostics, text-case, gaf

## Scope

`lua/config/keymaps.lua` defines every leader-prefixed and free-key global mapping. Plugin-owned maps (e.g. `<leader>ca` from `actions-preview.nvim`, telescope/snacks pickers) live with the plugin spec. Filetype-local maps live in `after/ftplugin/`.

## Highlights

- A custom **resize submode** (`<leader>ur`) consumes single keys via `vim.fn.getcharstr` so you can hammer `hjkl` (and `HJKL` for x5 steps) without re-pressing the leader.
- `<leader>cr` is context-smart: it first tries a CSS class rename (cross-file, scss `&`-nesting aware) and a tag-pair rename (tagmatch) via `lua/config/rename.lua`, then falls through to a hand-rolled LSP rename that compensates for intelephense's `$` sigil bug — when the cursor sits on `$`, it advances one column (restored if the rename is cancelled), strips/re-prepends the sigil around the user input, and applies the workspace edit manually with `client:request`. See [config-rename](config-rename.md) and memory `nvim_php_rename.md`.
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
| `<leader>ur` | n | resize submode | Loop on `hjkl`/`HJKL`/`=` |

### Move lines
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<A-j>` / `<A-k>` | n | `:m` + `==` | Move line down/up |
| `<A-j>` / `<A-k>` | v | `:m` + `gv=gv` | Move selection down/up |

### Save / Buffers
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<C-s>` | n,i,x,s | `:w` + `<esc>` | Save file |
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
| `<leader>cr` | n | smart rename: class → tag → LSP | Rename class/tag/symbol |
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
| `<leader>uf` | n | flip `g:disable_autoformat` | Toggle format-on-save |

### Case conversion (text-case.nvim)
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>cv` | n | `vim.ui.select` picker | Convert identifier under cursor: snake_case / camelCase / PascalCase / UPPER_CASE / kebab-case |

The token is extracted with a hyphen-aware scan (text-case's own `current_word()` stops at `-`, which would truncate kebab-case identifiers), then converted via `textcase.conversions.stringcase` and written back with `nvim_buf_set_text`.

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

### Loclist
| Key | Mode | Action | Desc |
| --- | --- | --- | --- |
| `<leader>xl` | n | toggle ll | Toggle loclist |

(`<leader>xq` toggle-quickfix now lives in the quicker.nvim spec, not here.)

## Links

- Related [config-init](config-init.md)
- Related [config-autocmds](config-autocmds.md)
- `<leader>cr` class/tag backends: [config-rename](config-rename.md), [editor-tagmatch](editor-tagmatch.md)
- LSP rename context: [ftplugin-php](ftplugin-php.md), memory `nvim_php_rename.md`
- GAF `gx` hook: `lua/gaf/keymaps.lua` (`open_phab_under_cursor`)
- Plugins referenced: `hlslens`, `Snacks.picker`, `conform.nvim`, `text-case.nvim`, `actions-preview.nvim`

## Notes

- `<leader>cr` routes CSS-class and tag contexts to `config/rename.lua` first; the LSP path only fires when at least one attached client supports `textDocument/rename`; otherwise it warns and bails.
- After a successful LSP rename it runs `silent! wall`; the class-rename backend likewise writes every touched file.
- `<leader>uf` flips a global, not a buffer-local — `conform.format_after_save` reads `vim.g.disable_autoformat`.
- The resize submode redraws and prints a hint line; press `q` or `<Esc>` (or any non-listed key) to leave.
