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
| `<leader><leader>` | n | Find files (resumes last query) | fff.nvim |
| `<leader>,` | n | Buffers | snacks.picker |
| `<leader>fr` | n | Recent files | snacks.picker |
| `<leader>fc` | n | Find config file | snacks.picker |
| `<leader>fR` | n | Rename file | snacks.rename |
| `<leader>ha` | n | Harpoon add | harpoon |
| `<leader>hh` | n | Harpoon menu | harpoon |
| `<leader>1`–`<leader>8` | n | Harpoon slot 1–8 | harpoon |
| `<C-o>` / `<C-i>` | n | Jumplist back/forward (Jumppack preview) | Jumppack.nvim |
| `<leader>;` | n | Dropbar pick — h=parent, l=child, i=fuzzy, q=close | dropbar.nvim |
| `[;` / `];` | n | Goto context start / select next context | dropbar.nvim |
| `<leader>oo` | n | Other: pick related file | other.nvim |
| `<leader>os` | n | Other: pick (split) | other.nvim |
| `<leader>ov` | n | Other: pick (vsplit) | other.nvim |

## Search

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>sg` | n | Live grep (resumes last query) | fff.nvim |
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
| `<leader>cS` | n, x | Structural search-replace | ssr.nvim |
| `<leader>co` | n | TS: organize imports | typescript-tools |
| `<leader>cM` | n | TS: add missing imports | typescript-tools |
| `<leader>cU` | n | TS: remove unused imports | typescript-tools |
| `<leader>cR` | n | TS: remove unused | typescript-tools |
| `<leader>cF` | n | TS: fix all | typescript-tools |
| `<leader>cD` | n | TS: go to source definition | typescript-tools |
| `:w` (TS/JS) | n | Auto: add missing + remove unused imports on save (`:let g:disable_ts_organize_on_save = 1` to disable) | productivity.lua |
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
| `]c` / `[c` | n | Next/Prev hunk | gitsigns |
| `ih` | o, x | Select hunk (gitsigns textobj) | gitsigns |

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
| `<leader>tC` | n | Run last test with coverage |

### GAF profile (`GAF=1 nvim`)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>tp` | n | Run file with xdebug profile — PHP buffers |
| `<leader>tP` | n | Replay last profile run |
| `<leader>tx` | n | Setup test infra (`bin/run-tests setup`) — PHP buffers |
| `<leader>tX` | n | Shutdown test infra — PHP buffers |
| `<leader>tm` | n | Run UI test (mobile) — `ui-tests/*.spec.ts` |
| `<leader>tw` | n | Run UI test (watch) — `ui-tests/*.spec.ts` |

> In markdown buffers, `<leader>t*` is owned by Checkmate (see Markdown todos). Neotest keys still work outside markdown.

## Debugging (DAP)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>db` | n | Toggle breakpoint (persistent across sessions) |
| `<leader>dB` | n | Conditional breakpoint (prompts for expression in target language) |
| `<leader>dC` | n | Clear all breakpoints |
| `]b` / `[b` | n | Next / prev breakpoint |
| `<leader>dc` | n | Continue |
| `<leader>di` | n | Step into |
| `<leader>do` | n | Step over |
| `<leader>dO` | n | Step out |
| `<leader>dt` | n | Terminate |
| `<leader>du` | n | Toggle DAP UI (nvim-dap-view) |
| `<leader>de` | n, v | Watch expression |
| `<leader>dl` | n | Run last |

> Breakpoints persist via `persistent-breakpoints.nvim` — auto-load on `BufReadPost`. Must toggle via `<leader>db` (not raw `dap.toggle_breakpoint`) to save state.

### GAF profile (`GAF=1 nvim`)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>dx` | n | GAF xdebug: start port-forward (`:GafXdebugStart`) |
| `<leader>dX` | n | GAF xdebug: stop port-forward (`:GafXdebugStop`) |
| `<leader>dv` | n | GAF xdebug: validate IDE setup |
| `<leader>dD` | n | Toggle `GAF_DEBUG=1` (neotest passes `--debug`) |

## Database (`<leader>D` — vim-dadbod-ui)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Du` | n | DB: toggle UI |
| `<leader>Df` | n | DB: find buffer |
| `<leader>Da` | n | DB: add connection |
| `<leader>Dr` | n | DB: rename buffer |
| `<leader>Dq` | n | DB: last query info |

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
| `za` | n | Toggle fold under cursor | native (treesitter folds) |
| `zR` / `zM` | n | Open / close all folds | native (treesitter folds) |
| `zj` / `zk` | n | Jump to next / prev fold | native |
| `<leader>zx` | n | Recompute folds | config/keymaps.lua |
| `gx` | n | Open URL/file/Phab `D####`/`T####` under cursor | config/keymaps.lua |

## Obsidian — `<leader>n*`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>nf` | n | Find note (quick switch) |
| `<leader>ns` | n | Search vault content |
| `<leader>ng` | n | Tags picker |
| `<leader>nb` | n | Backlinks |
| `<leader>nl` | n | Links in note |
| `<leader>nF` | n | Follow link |
| `<leader>no` | n | Open in Obsidian app |
| `<leader>nW` | n | Switch workspace |
| `<leader>nd` / `<leader>ny` / `<leader>nT` | n | Today / yesterday / tomorrow daily |
| `<leader>nR` | n | Weekly review |
| `<leader>nc` | n | Capture to inbox |
| `<leader>nn` | n | New note (raw, inbox) |
| `<leader>np` / `<leader>nm` / `<leader>nu` / `<leader>nD` | n | New project / meeting / bug / decision |
| `<leader>nk` / `<leader>nP` / `<leader>nS` / `<leader>nB` | n | New concept / person / snippet / book |
| `<leader>ni` | n | Insert template at cursor |
| `<leader>nr` | n | Rename note (refactor links) |
| `<leader>nI` | n | Paste image |
| `<leader>nL` | v | Link selection |
| `<leader>nX` | v | Extract selection → note |
| `<leader>nt` | n | Toggle checkbox |
| `<leader>nC` | n | Table of contents |

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

### vim-abolish — case coercion (`cr` prefix)

Operates on word under cursor. Case-preserving rename across forms.

| Key | Result on `myVar` | Style |
|-----|-------------------|-------|
| `crs` | `my_var` | snake_case |
| `crc` | `myVar` | camelCase |
| `crm` | `MyVar` | MixedCase / PascalCase |
| `cru` | `MY_VAR` | UPPER_SNAKE |
| `cr-` | `my-var` | kebab-case |
| `cr.` | `my.var` | dot.case |
| `crt` | `My Var` | Title Case |

Multi-form replace: `:%S/facilit{y,ies}/building{,s}/g` swaps singular + plural in one pass.

### Filetype tricks — `after/ftplugin/`

| Trigger | FT | Result |
|---------|------|--------|
| `$$` (insert) | php | Expands to `$this->`. Skips if previous char is word/`$` (so `$$foo` stays literal). |
| `fn<Tab>` | php | Arrow function snippet `fn($x) => ` (alias to existing `afn`) |

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
| `<leader>ud` | n | Toggle diagnostics (conflicts with duck `<leader>ud*` prefix — 2-char fires after timeout) |
| `<leader>uM` | n | Toggle markdown render (markview) |
| `<leader>udd` / `<leader>uda` | n | Hatch duck (slow / fast) |
| `<leader>udk` / `<leader>udK` | n | Cook one duck / cook all |

## Quit — `<leader>q`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>qq` | n | Quit all |

## Terminal

| Key | Mode | Description |
|-----|------|-------------|
| `<esc><esc>` | t | Exit terminal mode |

## Flutter — `<leader>F*`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Fr` | n | Flutter run |
| `<leader>FR` | n | Flutter hot reload |
| `<leader>FM` | n | Flutter hot restart |
| `<leader>Fq` | n | Flutter quit |
| `<leader>Fd` | n | Flutter devices |
| `<leader>Fe` | n | Flutter emulators |
| `<leader>Fl` | n | Flutter log toggle |
| `<leader>Fo` | n | Flutter outline |
| `<leader>Fp` / `<leader>FP` | n | Pub get / Pub upgrade |
| `<leader>Fc` | n | Flutter LSP restart |

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

## Emmet (emmet-vim) — `<C-y>` leader

Active in: `html`, `eruby`, `css`/`scss`/`sass`/`less`, `jsx`/`tsx`, `vue`, `svelte`, `htmldjango`. ERB inherits HTML snippet set.

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ce` | n | Expand abbreviation (buffer-local in emmet filetypes) |
| `<C-y>,` | i, n, v | Expand abbreviation (e.g. `div.card>h2{Title}+p.lead`) / wrap selection |
| `<C-y>;` | i, n | Expand inline (no newlines) |
| `<C-y>u` | n | Update tag (change `div` → `span`, etc.) |
| `<C-y>d` | n, v | Balance tag inward (select inner) |
| `<C-y>D` | n, v | Balance tag outward (select outer) |
| `<C-y>n` / `<C-y>N` | n | Next / prev edit point |
| `<C-y>i` | n | Update image size (HTML `<img>` width/height from file) |
| `<C-y>m` | n | Merge lines into single tag |
| `<C-y>k` | n | Remove tag |
| `<C-y>j` | n | Split / join tag |
| `<C-y>/` | n | Toggle HTML/CSS comment |
| `<C-y>a` | n | Make anchor from URL on line |
| `<C-y>A` | n | Make quoted text from URL on line |

ERB examples:
- `ul>li.item*3{<%= item %>}` then `<C-y>,` → 3 `<li class="item">` each containing the ERB output tag
- `div.card>h2{Title}+p.lead{<%= @user.bio %>}` → full card block
- Visual-select a region, `<C-y>,`, type `div.container` → wraps selection in `<div class="container">`

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

`<leader>a` ai/claude · `<leader>b` buffer · `<leader>c` code · `<leader>cs` swap · `<leader>cv` case convert · `<leader>d` debug · `<leader>D` database · `<leader>f` find · `<leader>F` flutter · `<leader>g` git · `<leader>h` harpoon · `<leader>k` docs (devdocs/nvimdocs) · `<leader>m` multicursor · `<leader>n` obsidian · `<leader>o` overseer/other · `<leader>q` quit · `<leader>r` rails · `<leader>s` search · `<leader>S` snippets · `<leader>t` todo/test · `<leader>u` ui · `<leader>ud` duck · `<leader>w` window · `<leader>x` diagnostics · `<leader>X` xdebug profile · `g` goto · `gs` surround

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
