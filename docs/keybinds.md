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
| `<leader>ur` | n | Resize submode (hjkl, H/J/K/L=×5, ==equal, q=quit) | config/keymaps.lua |
| `<C-h/j/k/l>` | n | Window/tmux pane nav | vim-tmux-navigator |
| `q` | n | Close help/qf/lspinfo/man/notify/grug-far/blame | config/autocmds.lua |

## Files / Explorer / Pickers

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>e` | n | Explorer (Oil) | canola.nvim (oil fork) |
| `-` | n | Open parent directory (Oil) | canola.nvim (oil fork) |
| `<leader>fn` | n | New file | config/keymaps.lua |
| `<leader>ff` | n | Find files | snacks.picker |
| `<leader><leader>` | n | Find files (resumes last query) | fff.nvim |
| `<leader>,` | n | Buffers | snacks.picker |
| `<leader>fr` | n | Recent files | snacks.picker |
| `<leader>fc` | n | Find config file | snacks.picker |
| `<leader>fR` | n | Rename file | snacks.rename |
| `<leader>fo` | n | Open current file's dir in Finder | fff.nvim |
| `<leader>ha` | n | Harpoon add | harpoon |
| `<leader>hh` | n | Harpoon menu | harpoon |
| `<leader>1`–`<leader>8` | n | Harpoon slot 1–8 | harpoon |
| `<C-o>` / `<C-i>` | n | Jumplist back/forward (Jumppack preview) | Jumppack.nvim |
| `<leader>oo` | n | Other: pick related file | other.nvim |
| `<leader>os` | n | Other: pick (split) | other.nvim |
| `<leader>oV` | n | Other: pick (vsplit) | other.nvim |

## Search

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>sg` | n | Grep workspace (async rg) | snacks.picker |
| `<leader>sz` | n | Fuzzy grep (frecency-first, partial on big repos) | fff.nvim |
| `<leader>/` | n | Seek: progressive file → grep (`<C-e>` toggle, `<Tab>` multi-select) | seeker.nvim |
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
| `]]` / `[[` | n | Next/prev occurrence of word under cursor (text search) | config/keymaps.lua |
| `<leader>ca` | n, v | Code action (preview) | actions-preview |
| `<leader>cA` | n | Source action | config/keymaps.lua |
| `<leader>cr` | n | Smart rename: CSS class (cross-file, scss `&`-aware) → tag pair → LSP symbol (PHP `$` sigil aware) | config/rename.lua + keymaps.lua |
| `<leader>cf` | n, v | Format file/selection (conform) | plugins/formatting.lua |
| `<leader>ci` | n | Toggle inlay hints | config/keymaps.lua |
| `<leader>cd` | n | Line diagnostics float | config/keymaps.lua |
| `<leader>U` | n | Undo tree (undotree) | undotree |
| `<leader>co` | n | TS: organize imports | typescript-tools |
| `<leader>cM` | n | TS: add missing imports | typescript-tools |
| `<leader>cU` | n | TS: remove unused imports | typescript-tools |
| `<leader>cR` | n | TS: remove unused | typescript-tools |
| `<leader>cF` | n | TS: fix all | typescript-tools |
| `<leader>cD` | n | TS: go to source definition | typescript-tools |
| `:w` (TS/JS) | n | Auto: add missing + remove unused imports on save (`:let g:disable_ts_organize_on_save = 1` to disable) | productivity.lua |
| `<leader>csa` / `<leader>csA` | n | Swap with next/prev arg | treesitter |

## Git

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>gg` | n | Lazygit | snacks |
| `<leader>gl` | n | Line history — commits touching current line; `<CR>` opens commit read-only (`:Gedit <sha>`, no checkout) | util.line_history |
| `<leader>gl` | v | Range history — commits touching the selection | util.line_history |
| `<leader>gf` | n | File history — commits touching current file (`--follow`); `<CR>` opens commit read-only | util.line_history |
| `<leader>gd` | n | Diff current file vs index (`:Gdiffsplit`) | fugitive |
| `<leader>gp` | n | Preview hunk (inline) | gitsigns |
| `<leader>gr` | n | Reset hunk | gitsigns |
| `<leader>gr` | v | Reset selected lines | gitsigns |
| `]c` / `[c` | n | Next/Prev hunk (centers cursor) | gitsigns |
| `co` / `ct` / `cb` / `c0` | n | Conflict: take ours / theirs / both / none | git-conflict |
| `]x` / `[x` | n | Next/Prev conflict | git-conflict |

## Diagnostics / Quickfix

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>cd` | n | Line diagnostics float | config/keymaps.lua |
| `[d` / `]d` | n | Prev/Next diagnostic (auto-opens float) | config/keymaps.lua |
| `[e` / `]e` | n | Prev/Next error | config/keymaps.lua |
| `[w` / `]w` | n | Prev/Next warning | config/keymaps.lua |
| `<leader>xx` | n | Trouble: diagnostics toggle | trouble |
| `<leader>xq` | n | Toggle quickfix (quicker.nvim, editable) | quicker.nvim |
| `<leader>xl` | n | Toggle loclist | config/keymaps.lua |

> Inside qf buffer (quicker.nvim): `>` expand context, `<` collapse, edit lines + `:w` to apply to source files.

## Tasks (Overseer)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>or` | n | Run task |
| `<leader>oc` | n | Run shell command |
| `<leader>ol` | n | Open task output in float |
| `<leader>oh` | n | Open task output in hsplit |
| `<leader>ov` | n | Open task output in vsplit |
| `<leader>od` | n | Dispose task |

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

## Redash — `<leader>r*` (GAF=1 only)

`redash.nvim` (local: `~/redash.nvim`) runs ad-hoc SQL through Redash's HTTP API
— no direct DB access needed. Registered **only** under the GAF profile (the
plugin spec returns nothing when `GAF` is unset, so `<leader>r` is free
otherwise). URL via `$REDASH_URL`, API key from `~/brainskey.txt`, default data
source `FLN-Redshift (Regular Access)`; results render via csvview.

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ro` | n | Open scratch SQL buffer (full tab) |
| `<leader>rr` | n, x | Run buffer / visual selection (in sql buffers) |
| `<leader>rt` | n | Browse schema sidebar (searchable tables/columns) |
| `<leader>rs` | n | Pick / switch data source |
| `<leader>rk` | n | Cancel the running query (local + Redash job) |

**In the result window:** `<CR>` row detail · `e` export (CSV/TSV/JSON/MD/clipboard) · `q`/`<Esc>` close · `<Tab>`/`<S-Tab>` next/prev column · `if`/`af` field text-objects (csvview).

**In the schema sidebar:** `<CR>` expand table / insert column · `i` insert name · `p` preview table · `/` filter · `f` fuzzy pick · `r` refresh · `q` close.

**Commands:** `:Redash` · `:RedashRun` · `:RedashSource` · `:RedashTables` · `:RedashCancel`.

## REST client (Kulala) — `<leader>R*`

`kulala.nvim` runs HTTP requests from `.http`/`.rest` files. The first five keys
work in any buffer (and lazy-load the plugin); the rest are scoped to
`http`/`rest` buffers. `curl` required, `jq` recommended for JSON formatting.

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Ro` | n | Open Kulala UI |
| `<leader>Rb` | n | Scratchpad (ad-hoc request buffer) |
| `<leader>Rs` | n, v | Send request under cursor / selection |
| `<leader>Ra` | n, v | Send all requests in file |
| `<leader>Rr` | n | Replay last request |
| `<leader>Rt` | n | Toggle headers/body view |
| `<leader>Ri` | n | Inspect parsed request |
| `<leader>RS` | n | Show response stats |
| `<leader>Rf` | n | Find request (picker) |
| `<leader>Rn` / `<leader>Rp` | n | Next / prev request |
| `<leader>Re` | n | Select environment |
| `<leader>Rc` / `<leader>RC` | n | Copy as cURL / paste from cURL |
| `<leader>Rj` | n | Open cookies jar |
| `<leader>Rg` | n | Download GraphQL schema |
| `<leader>Rq` | n | Close result window |
| `<leader>Rx` / `<leader>RX` | n | Clear global vars / cached files |

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
| `za` | n | Toggle fold under cursor | native |
| `zR` / `zM` | n | Open / close all folds | ufo (fold.lua) |
| `zr` / `zm` | n | Raise / lower fold level by one | ufo (fold.lua) |
| `z1`..`z5` | n | Fold to level N | fold.lua |
| `]z` / `[z` | n | Jump to next / prev closed fold | ufo (fold.lua) |
| `zj` / `zk` | n | Jump to next / prev fold | native |
| `zp` | n | Peek folded lines under cursor | ufo (fold.lua) |
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
| `gsd` | n | Surround delete (`gsdt` unwraps a tag pair, keeps content; `2gsdt` outer tag) | mini.surround |
| `gsf` / `gsF` | n | Surround find right/left | mini.surround |
| `gsh` | n | Surround highlight | mini.surround |
| `gsr` | n | Surround replace (two ids: `gsrtt` renames a tag via prompt) | mini.surround |
| `gsn` | n | Surround update n lines | mini.surround |
| `%` | n, x | Jump between `<tag>`/`</tag>` (treesitter; falls back to matchup/builtin) | tagmatch |
| `i%` / `a%` | x, o | Inner / around tag element (e.g. `di%`, `da%`) | tagmatch |
| `<leader>Se` | n | Edit snippet | scissors |
| `<leader>Sa` | n, x | Add snippet | scissors |
| `<CR>` | i | Accept completion / newline with pair expand | blink.cmp |
| `<C-Space>` | i | Show completion & docs | blink.cmp |

### Case conversion — `<leader>cv` (text-case.nvim)

`<leader>cv` opens a `vim.ui.select` picker over the identifier under the cursor
(hyphen-aware, so kebab-case tokens convert whole): snake_case, camelCase,
PascalCase, UPPER_CASE, kebab-case. Source: `lua/config/keymaps.lua` +
`text-case.nvim` conversions.

### Filetype tricks — `after/ftplugin/`

| Trigger | FT | Result |
|---------|------|--------|
| `$$` (insert) | php | Expands to `$this->`. Skips if previous char is word/`$` (so `$$foo` stays literal). |
| `fn<Tab>` | php | Arrow function snippet `fn($x) => ` (alias to existing `afn`) |

## UI Toggles — `<leader>u`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ur` | n | Resize submode (see Buffers / Windows) |
| `<leader>udd` / `<leader>uda` | n | Hatch duck (slow / fast) |
| `<leader>udk` / `<leader>udK` | n | Cook one duck / cook all |

## Terminal

| Key | Mode | Description |
|-----|------|-------------|
| `<esc><esc>` | t | Exit terminal mode |

## Flutter — `<leader>F*`

> Buffer-local to dart files (`after/ftplugin/dart.lua`) — these and the `<leader>F` group only appear when editing dart, not globally.

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

## Swift / Xcode — `<leader>X*`

> Buffer-local to swift files (`after/ftplugin/swift.lua`) — these and the `<leader>X` "xcode" group only appear when editing swift, not globally. Under `GAF=1` the `<leader>X*` maps are skipped entirely (GAF's global Xdebug maps own that prefix; use `:XcodebuildPicker`) — only the test/debug rows below are set. Build/run/test via xcodebuild.nvim; run `:XcodebuildSetup` once per project root.

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>XX` | n | All xcodebuild actions (picker) |
| `<leader>Xb` / `<leader>XB` | n | Build / build for testing |
| `<leader>Xr` | n | Build & run |
| `<leader>Xl` | n | Toggle build/run logs |
| `<leader>Xe` | n | Test explorer |
| `<leader>Xc` / `<leader>XC` | n | Toggle coverage / coverage report |
| `<leader>Xs` / `<leader>Xd` / `<leader>Xt` | n | Select scheme / device / test plan |
| `<leader>Xp` / `<leader>XP` | n | SwiftUI preview generate+show / toggle |
| `<leader>Xa` | n | Xcode code actions |
| `<leader>Xf` | n | Project manager (files/targets) |
| `<leader>Xq` | n | Quickfix line |
| `<leader>tr` / `<leader>tf` / `<leader>tt` | n | Run nearest test / class tests / test plan (xcodebuild, not neotest) |
| `<leader>ts` | v | Run selected tests |
| `<leader>t.` / `<leader>tF` | n | Repeat last tests / run failing tests |
| `<leader>td` | n | Debug nearest test |
| `<leader>dd` / `<leader>dr` | n | Build & debug / debug without build |

## Which-key groups

`<leader>b` buffer · `<leader>c` code · `<leader>cs` swap · `<leader>cv` case convert · `<leader>d` debug · `<leader>D` database · `<leader>f` find/files · `<leader>F` flutter (dart buffers) · `<leader>g` git · `<leader>h` harpoon · `<leader>k` docs (devdocs/nvimdocs) · `<leader>n` obsidian · `<leader>o` overseer/other · `<leader>r` redash (GAF=1) · `<leader>R` rest (kulala) · `<leader>s` search · `<leader>S` snippets · `<leader>t` test (neotest) · `<leader>u` ui · `<leader>ud` duck · `<leader>w` window · `<leader>x` diagnostics/quickfix · `<leader>X` xdebug profile (GAF=1 only) / xcode (swift buffers, non-GAF) · `g` goto · `gs` surround

## Known overlaps

- **`<leader>sR`** — snacks resume picker vs grug-far cword (n). Last-loaded wins; grug-far visual mode (`x`) safe.
- **`<C-p>` / `<C-n>`** — yanky yank-ring cycling (n). Blink.cmp uses its own keys in insert.
- **`q`** — global (no map) vs buffer-local close-window in help/qf/man/grug-far/blame.
- **`<CR>`** — blink.cmp in insert. Treesitter incremental-select start in normal / expand in visual (if enabled).

## Removed / replaced (history)

- `vim-abolish` removed — `cr*` coercions replaced by the `<leader>cv` text-case picker. `:S` subvert gone (use grug-far).
- `refjump.nvim` (`]r`/`[r`), `dropbar.nvim` (`<leader>;`), `nvim-bqf`, `better-ts-errors` (`<leader>dd`/`dx`), `markview.nvim` (`<leader>uM`), `checkmate.nvim` (`<leader>t*` markdown todos), `claude-code.nvim` (`<leader>a*`), `diagram.nvim`/`image.nvim`, `gruvbox-baby` all removed.
- `emmet-vim` (`<C-z>*`) removed — emmet now via `emmet_language_server` completions.
- `oil.nvim` swapped for the `canola.nvim` fork (same `<leader>e` / `-` keys, `main = "oil"`).
- `tagmatch.nvim/` local plugin folded into the repo as `lua/tagmatch/` (loaded eagerly from `init.lua`, no lazy spec). Keys unchanged (`%`, `i%`/`a%`); gained tag-pair rename via `<leader>cr`.
- `<leader>cr` upgraded from LSP-only rename to smart routing: CSS class (cross-file, scss `&`-aware) → tag pair (tagmatch) → LSP symbol.
- `<leader>cn` was `neogen` annotation. Now `ts-node-action`.
- `<leader>du` opened `nvim-dap-ui`. Now `nvim-dap-view`.
- `<leader>de` was DAP eval. Now `DapViewWatch`.
- `nvim-treesitter-endwise` reverted to `tpope/vim-endwise` (TS plugin broken on TS main branch).
- `<leader>j*` Chrome DevTools group removed — vendored `webconnect/` Go bridge, `phab-inline.nvim/` plugin, and `web*` util modules deleted.
- **Git overhaul** — `diffview.nvim` removed: `<leader>gd` is now `:Gdiffsplit`, `<leader>gf` is the line_history file-history picker. `mini.diff` removed: `<leader>gho`/`<leader>go` overlay gone — use `<leader>gp` inline hunk preview. `<leader>gb` blame, `<leader>gB`, `<leader>gt` line-blame toggle, `<leader>gc` git log, `<leader>gs` git status all removed. `<leader>g/`/`<leader>g*` git grep (`util.ggrep`) removed and the util deleted. gitsigns hunk stage/unstage/reset-buffer/blame-line dropped (stage via lazygit / `:Git`); only inline preview (`<leader>gp`) + reset (`<leader>gr`) survive, promoted off the `<leader>gh` prefix (group removed).
- `<leader>cS` `ssr.nvim` (structural search-replace) removed.
- `timber.nvim` (log injection, `<leader>l*`) removed.
- `<leader>ud` toggle-diagnostics removed — tiny-inline-diagnostic ignored `vim.diagnostic.enable`, and it collided with the duck `<leader>ud*` prefix. `<leader>ud` is now purely the duck group.
- `<leader>wr` resize submode → `<leader>ur` (moved under the `ui` group). `<leader>qq` quit-all and `<leader>zx` recompute-folds removed. `<leader>xQ` (quicker quickfix) merged into `<leader>xq`.
