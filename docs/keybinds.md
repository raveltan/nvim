# Neovim Keybindings Reference

Leader: `<space>`. Local leader: `\`. Modes: `n` normal, `i` insert, `v` visual, `x` visual-block, `s` select, `o` operator-pending, `t` terminal.

> Many plugin keymaps are filetype-scoped (loaded via `ft`/`event`) or buffer-local; collisions resolved by load order or buffer scope are noted at the bottom.

## Buffers / Windows

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>\|` | n | Vertical split | config/keymaps.lua |
| `<leader>-` | n | Horizontal split | config/keymaps.lua |
| `<S-h>` | n | Prev buffer | config/keymaps.lua |
| `<S-l>` | n | Next buffer | config/keymaps.lua |
| `<leader>bo` | n | Close other buffers | config/keymaps.lua |
| `<leader>bd` | n | Delete buffer | mini.bufremove |
| `<leader>bD` | n | Delete buffer (force) | mini.bufremove |
| `<C-Up>` / `<C-Down>` | n | Resize height | config/keymaps.lua |
| `<C-Left>` / `<C-Right>` | n | Resize width | config/keymaps.lua |
| `<leader>wr` | n | Resize submode (hjkl, H/J/K/L=×5, ==equal, q=quit) | config/keymaps.lua |
| `<C-h/j/k/l>` | n | Window/tmux pane nav | vim-tmux-navigator |
| `q` | n | Close help/qf/lspinfo/man/notify/grug-far/blame | config/autocmds.lua |

## Files / Explorer / Pickers

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>e` | n | Explorer (Oil) | oil.nvim |
| `-` | n | Open parent directory (Oil) | oil.nvim |
| `<leader>fn` | n | New file | config/keymaps.lua |
| `<leader>ff` | n | Find files | snacks.picker |
| `<leader><leader>` | n | Find files (alias) | snacks.picker |
| `<leader>,` | n | Buffers | snacks.picker |
| `<leader>fr` | n | Recent files | snacks.picker |
| `<leader>fc` | n | Find config file | snacks.picker |
| `<leader>fR` | n | Rename file | snacks.rename |
| `<leader>ha` | n | Harpoon add | harpoon |
| `<leader>hh` | n | Harpoon menu | harpoon |
| `<leader>1`–`<leader>4` | n | Harpoon slot 1–4 | harpoon |
| `<C-o>` / `<C-i>` | n | Jumplist back/forward (Jumppack preview) | Jumppack.nvim |
| `<leader>;` | n | Dropbar pick — h=parent, l=child, i=fuzzy, q=close | dropbar.nvim |
| `[;` / `];` | n | Goto context start / select next context | dropbar.nvim |
| `<leader>oo` | n | Other: pick related file | other.nvim |
| `<leader>os` | n | Other: pick (split) | other.nvim |
| `<leader>ov` | n | Other: pick (vsplit) | other.nvim |

## Search

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>sg` | n | Live grep | snacks.picker |
| `<leader>sw` | n, x | Grep word/selection | snacks.picker |
| `<leader>sb` | n | Buffer lines | snacks.picker |
| `<leader>sh` | n | Help pages | snacks.picker |
| `<leader>sk` | n | Keymaps | snacks.picker |
| `<leader>sc` | n | Commands | snacks.picker |
| `<leader>sd` | n | Diagnostics | snacks.picker |
| `<leader>sR` | n | Resume last picker / Grug-far word under cursor (last-load wins) | snacks.picker / grug-far |
| `<leader>ss` | n | Document symbols | snacks.picker |
| `<leader>sS` | n | Workspace symbols | snacks.picker |
| `<leader>sj` | n | Jumplist | snacks.picker |
| `<leader>sm` | n | Marks | snacks.picker |
| `<leader>s/` | n | Search history | snacks.picker |
| `<leader>s:` | n | Command history | snacks.picker |
| `<leader>s.` | n | Grep in current file dir | snacks.picker |
| `<leader>st` | n | Todo comments | snacks.picker |
| `<leader>sr` | n | Search / replace (grug-far) | grug-far |
| `<leader>sR` | x | Grug-far: visual selection | grug-far |
| `<leader>su` | n | Undo history picker | telescope-undo |
| `gw` | n | Grep word under cursor | config/keymaps.lua |

## LSP

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `K` | n | Hover docs | config/keymaps.lua |
| `gd` | n | Go to definition | snacks.picker |
| `gr` | n | References | snacks.picker |
| `gI` | n | Implementations | snacks.picker |
| `gy` | n | Type definitions | snacks.picker |
| `gD` / `gR` / `gY` / `gM` | n | Peek (Glance) def/refs/type/impl | glance.nvim |
| `]r` / `[r` | n | Cycle LSP references inline | refjump.nvim |
| `]]` / `[[` | n | Next/Prev reference | illuminate |
| `<leader>ca` | n, v | Code action (preview) | actions-preview |
| `<leader>cA` | n | Source action | config/keymaps.lua |
| `<leader>cr` | n | Rename symbol (PHP `$` sigil aware) | config/keymaps.lua |
| `<leader>cf` | n | Format file (conform) | config/keymaps.lua |
| `<leader>ci` | n | Toggle inlay hints | config/keymaps.lua |
| `<leader>cd` | n | Line diagnostics float | config/keymaps.lua |
| `<leader>cu` | n | Undo tree (undotree) | undotree |
| `<leader>cj` | n | Split/join block (treesj) | treesj |
| `<leader>cn` | n | Treesitter node action | ts-node-action |
| `<leader>cS` | n, x | Structural search-replace | ssr.nvim |
| `<leader>co` | n | TS: organize imports | typescript-tools |
| `<leader>cM` | n | TS: add missing imports | typescript-tools |
| `<leader>cU` | n | TS: remove unused imports | typescript-tools |
| `<leader>cR` | n | TS: remove unused | typescript-tools |
| `<leader>cF` | n | TS: fix all | typescript-tools |
| `<leader>cD` | n | TS: go to source definition | typescript-tools |
| `<leader>csa` / `<leader>csA` | n | Swap with next/prev arg | treesitter |
| `<leader>dd` | n | Better-ts-errors toggle (TS) / Diagram show (md) | better-ts-errors / diagram |
| `<leader>dx` | n | Better-ts-errors: go to def (TS) | better-ts-errors |

## Git

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>gg` | n | Lazygit | snacks |
| `<leader>gc` | n | Git log | snacks.picker |
| `<leader>gs` | n | Git status | snacks.picker |
| `<leader>gd` | n | Diff view (open) | diffview |
| `<leader>gf` | n | File history | diffview |
| `<leader>gb` | n | Blame file (author column) | gitsigns |
| `<leader>gB` | n | Blame interactive (fugitive) | fugitive |
| `<leader>gt` | n | Toggle line blame virt text | gitsigns |
| `<leader>gl` | n | (worktree/log — see git.lua) | workflow.lua |
| `<leader>g/` | n | Git grep (prompt) | util.ggrep |
| `<leader>g/` | v | Git grep selection | util.ggrep |
| `<leader>g*` | n | Git grep word under cursor | util.ggrep |
| `<leader>go` | n | Toggle mini.diff overlay | mini.diff |
| `]c` / `[c` | n | Next/Prev hunk | gitsigns |
| `<leader>ghs` | n, v | Stage hunk | gitsigns |
| `<leader>ghr` | n, v | Reset hunk | gitsigns |
| `<leader>ghS` | n | Stage buffer | gitsigns |
| `<leader>ghR` | n | Reset buffer | gitsigns |
| `<leader>ghu` | n | Undo stage hunk | gitsigns |
| `<leader>ghp` | n | Preview hunk | gitsigns |
| `<leader>ghd` / `<leader>ghD` | n | Diff this / vs last commit | gitsigns |
| `ih` | o, x | Select hunk (gitsigns or mini.diff textobj) | gitsigns / mini.diff |

## Diagnostics / Quickfix

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>cd` | n | Line diagnostics float | config/keymaps.lua |
| `[d` / `]d` | n | Prev/Next diagnostic (auto-opens float) | config/keymaps.lua |
| `[e` / `]e` | n | Prev/Next error | config/keymaps.lua |
| `[w` / `]w` | n | Prev/Next warning | config/keymaps.lua |
| `<leader>ud` | n | Toggle diagnostics | config/keymaps.lua |
| `<leader>xx` | n | Trouble: diagnostics toggle | trouble |
| `<leader>xq` | n | Toggle quickfix | config/keymaps.lua |
| `<leader>xQ` | n | Toggle quickfix (quicker.nvim, editable) | quicker.nvim |
| `<leader>xl` | n | Toggle loclist | config/keymaps.lua |

> Inside qf buffer (quicker.nvim): `>` expand context, `<` collapse, edit lines + `:w` to apply to source files.

## Tasks (Overseer)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>or` | n | Run task |
| `<leader>oc` | n | Run shell command |
| `<leader>ot` | n | Toggle task list |
| `<leader>ol` | n | Task action |

## Refactoring (`<leader>R` — buffer-local on supported FT)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Re` | v | Refactor (select) |
| `<leader>Rf` | v | Extract function |
| `<leader>Rv` | v | Extract variable |
| `<leader>Ri` | n, v | Inline variable |

## Testing (Neotest) — `<leader>t*`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>tr` | n | Run nearest test |
| `<leader>tf` | n | Run file tests |
| `<leader>ts` | n | Toggle summary |
| `<leader>to` | n | Show output |
| `<leader>tO` | n | Toggle output panel |
| `<leader>td` | n | Debug nearest test |
| `<leader>tl` | n | Run last test |
| `<leader>tS` | n | Stop test |
| `<leader>tm` | n | Run UI test (mobile) — buffer-local on `ui-tests/*.spec.ts` |
| `<leader>tw` | n | Run UI test (watch) — buffer-local on `ui-tests/*.spec.ts` |
| `<leader>tx` | n | Setup test infra — buffer-local on PHP in `fl-gaf` |
| `<leader>tX` | n | Shutdown test infra — buffer-local on PHP in `fl-gaf` |

> In markdown buffers, `<leader>t*` is owned by Checkmate (see Markdown todos). Neotest keys still work outside markdown.

## Debugging (DAP)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>db` | n | Toggle breakpoint |
| `<leader>dB` | n | Conditional breakpoint |
| `<leader>dc` | n | Continue |
| `<leader>di` | n | Step into |
| `<leader>do` | n | Step over |
| `<leader>dO` | n | Step out |
| `<leader>dt` | n | Terminate |
| `<leader>du` | n | Toggle DAP UI (nvim-dap-view) |
| `<leader>de` | n, v | Watch expression |
| `<leader>dl` | n | Run last |

## Database (`<leader>D` — vim-dadbod-ui)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Du` | n | DB: toggle UI |
| `<leader>Df` | n | DB: find buffer |
| `<leader>Da` | n | DB: add connection |
| `<leader>Dr` | n | DB: rename buffer |
| `<leader>Dq` | n | DB: last query info |

## REPL (`<leader>i` — iron.nvim)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>is` | n | Toggle REPL |
| `<leader>ir` | n | Restart REPL |
| `<leader>ic` | n, o | Send motion |
| `<leader>iv` | x | Send visual selection |
| `<leader>il` | n | Send line |
| `<leader>if` | n | Send file |
| `<leader>iu` | n | Send until cursor |
| `<leader>im` | n | Send mark |
| `<leader>iM` | n, x | Mark motion / mark visual |
| `<leader>id` | n | Remove mark |
| `<leader>ix` | n | Interrupt |
| `<leader>iq` | n | Exit |
| `<leader>iC` | n | Clear |

## Navigation / Motion

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `s` | n, x, o | Flash jump | flash.nvim |
| `S` | n, x, o | Flash Treesitter | flash.nvim |
| `]f` / `[f` | n, x, o | Next/Prev function | treesitter |
| `]a` / `[a` | n, x, o | Next/Prev argument | treesitter |
| `af` / `if` | x, o | Around/Inside function | treesitter |
| `ac` / `ic` | x, o | Around/Inside class | treesitter |
| `aa` / `ia` | x, o | Around/Inside argument | treesitter |
| `<C-d>` / `<C-u>` | n | Half page down/up (centered) | config/keymaps.lua |
| `n` / `N` | n | Next/Prev search (centered, hlslens) | config/keymaps.lua |
| `zR` / `zM` | n | Open / close all folds | UFO |
| `zp` | n | Peek fold | UFO |
| `gx` | n | Open URL/file/Phab `D####`/`T####` under cursor | config/keymaps.lua |

### AST nav (treewalker) — `<leader>n`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>nk` / `<leader>nj` | n, v | AST up / down |
| `<leader>nh` / `<leader>nl` | n, v | AST parent / child |
| `<leader>nK` / `<leader>nJ` | n | AST swap up / down |

## Editing

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<C-s>` | n, i, x, s | Save file | config/keymaps.lua |
| `<A-j>` / `<A-k>` | n, v | Move line/selection down/up | config/keymaps.lua |
| `<` / `>` | v | Indent (keep selection) | config/keymaps.lua |
| `<leader>p` | x | Paste without overwrite | config/keymaps.lua |
| `J` | n | Join lines (preserve cursor) | config/keymaps.lua |
| `<esc>` | n | Clear search highlights | config/keymaps.lua |
| `y` / `p` / `P` | n, x | Yank / put after / put before (yanky) | yanky |
| `<C-p>` / `<C-n>` | n | Prev/Next yank entry | yanky |
| `<C-a>` / `<C-x>` | n, v | Increment / decrement | dial |
| `u` / `<C-r>` | n | Undo / redo (with region flash) | highlight-undo |
| `gsa` | n, x | Surround add | mini.surround |
| `gsd` | n | Surround delete | mini.surround |
| `gsf` / `gsF` | n | Surround find right/left | mini.surround |
| `gsh` | n | Surround highlight | mini.surround |
| `gsr` | n | Surround replace | mini.surround |
| `gsn` | n | Surround update n lines | mini.surround |
| `<leader>Se` | n | Edit snippet | scissors |
| `<leader>Sa` | n, x | Add snippet | scissors |
| `<CR>` | i | Accept completion / newline with pair expand | blink.cmp |
| `<C-Space>` | i | Show completion & docs | blink.cmp |

### Multicursor — `<leader>m`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>mn` / `<leader>mN` | n, x | Add cursor at next/prev match |
| `<leader>ms` / `<leader>mS` | n, x | Skip match next/prev |
| `<leader>ma` | n, x | Add cursor at all matches |
| `<leader>mj` / `<leader>mk` | n, x | Add cursor on line below/above |
| `<leader>mJ` / `<leader>mK` | n, x | Skip line down/up |
| `<leader>mx` | n, x | Delete cursor under main |
| `<leader>mr` | n | Restore cursors |
| `<leader>ml` | n, x | Align cursors to same column |
| `<leader>mp` | x | Split visual selection by regex |
| `<leader>mt` | x | Transpose text between cursors |
| `<C-q>` | n, x | Toggle cursor |
| `<C-LeftMouse>` | n | Toggle cursor at click |
| `<Tab>` / `<S-Tab>` | n, x | Cycle main cursor (in cursor layer) |
| `<Esc>` | n | Clear all cursors (in cursor layer) |

## UI Toggles — `<leader>u`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>uf` | n | Toggle format-on-save |
| `<leader>ud` | n | Toggle diagnostics |
| `<leader>uM` | n | Toggle markdown render (markview) |
| `<leader>uz` | n | Zen mode |

## Sessions / Quit — `<leader>q`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>qq` | n | Quit all |
| `<leader>qs` | n | Restore session |
| `<leader>qS` | n | Select session |
| `<leader>ql` | n | Restore last session |
| `<leader>qd` | n | Don't save current session |

## Terminal

| Key | Mode | Description |
|-----|------|-------------|
| `<esc><esc>` | t | Exit terminal mode |

## HTTP (hurl.nvim) — `<leader>H`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>H` | v | Run selection |
| `<leader>Ha` | n | Run all requests |
| `<leader>Hs` | n | Run request at cursor |
| `<leader>He` | n | Run up to entry |
| `<leader>Hm` | n | Toggle result mode |
| `<leader>Hv` | n | Run in verbose mode |

## Claude Code — `<leader>a`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ac` | n | Toggle Claude Code |
| `<leader>aC` | n | Claude Code continue |
| `<leader>ar` | n | Claude Code resume |
| `<leader>av` | n | Claude Code verbose |

## Rails (ror.nvim) — `<leader>r`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>rc` | n | Rails commands |
| `<leader>rg` | n | Generate |
| `<leader>rr` | n | List routes |
| `<leader>rs` | n | Schema columns |
| `<leader>rm` | n | DB migrate |
| `<leader>rk` | n | DB rollback |
| `<leader>rb` | n | Bundle install |
| `<leader>rC` | n | Rails console (terminal split) |
| `<leader>re` | n | Edit credentials |

## Checkmate (Markdown todos) — `<leader>t*` in markdown buffers

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>tt` | n, v | Toggle todo |
| `<leader>tc` / `<leader>tu` | n, v | Check / uncheck |
| `<leader>t=` / `<leader>t-` | n, v | Cycle next / previous state |
| `<leader>tn` | n, v | New todo |
| `<leader>tx` | n, v | Remove todo marker |
| `<leader>tR` | n, v | Remove all metadata |
| `<leader>ta` | n | Archive completed |
| `<leader>tf` | n | Find todo (picker) |
| `<leader>tv` | n | Set metadata value |
| `<leader>t]` / `<leader>t[` | n | Next / prev metadata tag |
| `<leader>tp` / `<leader>ts` / `<leader>td` | n | Insert priority / started / done metadata |

## Diagram (markdown/norg)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>dd` | n | Diagram: show at cursor in new tab (markdown/norg only) |

## Which-key groups

`<leader>a` claude · `<leader>b` buffer · `<leader>c` code · `<leader>cs` swap · `<leader>d` debug · `<leader>D` database · `<leader>f` find · `<leader>g` git · `<leader>gh` hunks · `<leader>H` hurl · `<leader>h` harpoon · `<leader>i` iron repl · `<leader>m` multicursor · `<leader>n` ast nav · `<leader>o` overseer · `<leader>q` quit/session · `<leader>r` rails · `<leader>R` refactor · `<leader>s` search · `<leader>S` snippets · `<leader>t` todo/test · `<leader>u` ui · `<leader>w` window · `<leader>x` diagnostics · `g` goto · `gs` surround

## Known overlaps

- **`<leader>sR`** — snacks resume picker vs grug-far cword (n). Last-loaded wins; grug-far visual mode (`x`) safe.
- **`<leader>dd`** — better-ts-errors (TS buffers) vs diagram.nvim (markdown/norg). Filetype-scoped, no real clash.
- **`<leader>t*`** — Checkmate (markdown only) vs neotest (everywhere). Buffer-scope resolves.
- **`<C-p>` / `<C-n>`** — yanky yank-ring cycling (n). Blink.cmp uses its own keys in insert.
- **`q`** — global (no map) vs buffer-local close-window in help/qf/man/grug-far/blame.
- **`<CR>`** — blink.cmp in insert. Treesitter incremental-select start in normal / expand in visual (if enabled).
- **`]]` / `[[`** — illuminate references. `[[` is also dropbar's binding alias? No — dropbar uses `[;`/`];` here.

## Removed / replaced (history)

- `<leader>cn` was `neogen` annotation. Now `ts-node-action`.
- `<leader>du` opened `nvim-dap-ui`. Now `nvim-dap-view`.
- `<leader>de` was DAP eval. Now `DapViewWatch`.
- `nvim-treesitter-endwise` reverted to `tpope/vim-endwise` (TS plugin broken on TS main branch).
