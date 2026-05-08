# Neovim Keybindings Reference

Leader key: `<space>`. Modes: `n` normal, `i` insert, `v` visual, `x` visual-block, `s` select, `o` operator-pending, `t` terminal.

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
| `<C-h/j/k/l>` | n | Window nav (tmux-navigator) | plugins/nav.lua |
| `q` | n | Close help/qf/lspinfo/man/notify/grug-far/blame | config/autocmds.lua |

## Files / Explorer / Pickers

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>e` | n | Explorer (Oil) | plugins/nav.lua |
| `-` | n | Open parent directory (Oil) | plugins/nav.lua |
| `<leader>fn` | n | New file | config/keymaps.lua |
| `<leader>ff` | n | Find files | snacks.picker |
| `<leader>fr` | n | Recent files | snacks.picker |
| `<leader>fb` | n | Buffers | snacks.picker |
| `<leader>fc` | n | Find config file | snacks.picker |
| `<leader>fR` | n | Rename file | snacks.picker |
| `<leader>ha` | n | Harpoon add | plugins/nav.lua |
| `<leader>hh` | n | Harpoon menu | plugins/nav.lua |
| `<leader>1`–`<leader>4` | n | Harpoon slot 1–4 | plugins/nav.lua |
| `<leader>oo` | n | Other: pick related file | plugins/other.lua |
| `<leader>os` | n | Other: pick (split) | plugins/other.lua |
| `<leader>ov` | n | Other: pick (vsplit) | plugins/other.lua |

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
| `<leader>sR` | n | Resume last picker | snacks.picker |
| `<leader>ss` | n | Document symbols | snacks.picker |
| `<leader>sS` | n | Workspace symbols | snacks.picker |
| `<leader>s"` | n | Registers | snacks.picker |
| `<leader>sm` | n | Marks | snacks.picker |
| `<leader>sj` | n | Jumplist | snacks.picker |
| `<leader>s/` | n | Search history | snacks.picker |
| `<leader>s:` | n | Command history | snacks.picker |
| `<leader>sG` | n | Grep in directory | snacks.picker |
| `<leader>s.` | n | Grep in current file dir | snacks.picker |
| `<leader>st` | n | Todo comments | plugins/editor.lua |
| `<leader>sr` | n | Search / replace (grug-far) | grug-far.nvim |
| `<leader>sR` | n | Grug-far: word under cursor | grug-far.nvim |
| `<leader>sR` | x | Grug-far: visual selection | grug-far.nvim |
| `gw` | n | Grep word under cursor | config/keymaps.lua |

> Note: `<leader>sS` is bound by both Snacks (workspace symbols) and SSR (structural replace). Last-loaded plugin wins.

## LSP

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `K` | n | Hover docs | config/keymaps.lua |
| `gd` | n | Go to definition | snacks.picker |
| `gr` | n | References | snacks.picker |
| `gI` | n | Implementations | snacks.picker |
| `gy` | n | Type definitions | snacks.picker |
| `gD` / `gR` / `gY` / `gM` | n | Peek (Glance) def/refs/type/impl | plugins/nav.lua |
| `<leader>ca` | n, v | Code action (preview) | actions-preview |
| `<leader>cA` | n | Source action | config/keymaps.lua |
| `<leader>cr` | n | Rename symbol (inc-rename) | config/keymaps.lua |
| `<leader>cf` | n | Format file (conform) | config/keymaps.lua |
| `<leader>ci` | n | Toggle inlay hints | config/keymaps.lua |
| `<leader>cu` | n | Undo tree | undotree |
| `<leader>cj` | n | Split/join block | treesj |
| `<leader>cn` | n | Generate annotation | neogen |
| `<leader>co` | n | TS: organize imports | ts-tools |
| `<leader>cM` | n | TS: add missing imports | ts-tools |
| `<leader>cU` | n | TS: remove unused imports | ts-tools |
| `<leader>cR` | n | TS: remove unused | ts-tools |
| `<leader>cF` | n | TS: fix all | ts-tools |
| `<leader>cD` | n | TS: go to source definition | ts-tools |
| `<leader>ct` | n | TS: project typecheck | tsc.nvim |
| `<leader>csa` / `<leader>csA` | n | Swap with next/prev arg | treesitter |

## Git

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>gg` | n | Lazygit | snacks |
| `<leader>gc` | n | Git log | snacks.picker |
| `<leader>gs` | n | Git status | snacks.picker |
| `<leader>gd` | n | Diff view | diffview |
| `<leader>gf` | n | File history | diffview |
| `<leader>gF` | n | Branch history | diffview |
| `<leader>gb` | n | Blame file | gitsigns |
| `<leader>gB` | n | Blame line (full commit) | gitsigns |
| `<leader>gq` | n | Close git view | plugins/git.lua |
| `]c` / `[c` | n | Next/Prev hunk | gitsigns |
| `<leader>ghs` | n, v | Stage hunk | gitsigns |
| `<leader>ghr` | n, v | Reset hunk | gitsigns |
| `<leader>ghS` | n | Stage buffer | gitsigns |
| `<leader>ghR` | n | Reset buffer | gitsigns |
| `<leader>ghu` | n | Undo stage hunk | gitsigns |
| `<leader>ghp` | n | Preview hunk | gitsigns |
| `<leader>ghd` / `<leader>ghD` | n | Diff this / vs last commit | gitsigns |
| `ih` | o, x | Select hunk (text object) | gitsigns |

## Diagnostics / Quickfix

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<leader>cd` | n | Line diagnostics float | config/keymaps.lua |
| `[d` / `]d` | n | Prev/Next diagnostic | config/keymaps.lua |
| `[e` / `]e` | n | Prev/Next error | config/keymaps.lua |
| `[w` / `]w` | n | Prev/Next warning | config/keymaps.lua |
| `<leader>ud` | n | Toggle diagnostics | config/keymaps.lua |
| `<leader>xx` | n | Trouble: diagnostics toggle | trouble |
| `<leader>xq` | n | Toggle quickfix | config/keymaps.lua |
| `<leader>xl` | n | Toggle loclist | config/keymaps.lua |
| `<leader>dd` | n | Toggle better-ts-errors | better-ts-errors |
| `<leader>dx` | n | Better-ts-errors: go to def | better-ts-errors |

## Tasks (Overseer)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>or` | n | Run task |
| `<leader>ot` | n | Toggle task list |
| `<leader>ol` | n | Task action |

## Refactoring

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>re` | v | Refactor (select) |
| `<leader>rf` | v | Extract function |
| `<leader>rv` | v | Extract variable |
| `<leader>ri` | n, v | Inline variable |

## Testing (Neotest)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Tr` | n | Run nearest test |
| `<leader>Tf` | n | Run file tests |
| `<leader>Ts` | n | Toggle summary |
| `<leader>To` | n | Show output |
| `<leader>TO` | n | Toggle output panel |
| `<leader>Td` | n | Debug nearest test |
| `<leader>Tl` | n | Run last test |
| `<leader>TS` | n | Stop test |
| `<leader>Tm` | n | Run UI test (mobile) — buffer-local on `ui-tests/*.spec.ts` |
| `<leader>Tw` | n | Run UI test (watch) — buffer-local on `ui-tests/*.spec.ts` |
| `<leader>Tx` | n | Setup test infra — buffer-local on PHP in `fl-gaf` |

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
| `<leader>du` | n | Toggle DAP UI |
| `<leader>de` | n, v | Eval expression |
| `<leader>dl` | n | Run last |

## Navigation / Motion

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `s` | n, x, o | Flash jump | flash.nvim |
| `S` | n, x, o | Flash Treesitter | flash.nvim |
| `]]` / `[[` | n | Next/Prev reference | illuminate |
| `]f` / `[f` | n, x, o | Next/Prev function | treesitter |
| `]a` / `[a` | n, x, o | Next/Prev argument | treesitter |
| `af` / `if` | x, o | Around/Inside function | treesitter |
| `ac` / `ic` | x, o | Around/Inside class | treesitter |
| `aa` / `ia` | x, o | Around/Inside argument | treesitter |
| `<CR>` | n | Start incremental select | treesitter |
| `<CR>` / `<BS>` | x | Expand / shrink selection | treesitter |
| `<C-d>` / `<C-u>` | n | Half page down/up (centered) | config/keymaps.lua |
| `n` / `N` | n | Next/Prev search (centered, hlslens) | config/keymaps.lua |
| `zR` / `zM` | n | Open / close all folds | UFO |
| `zp` | n | Peek fold | UFO |
| `gx` | n | Open URL / file / Phabricator `D####`/`T####` under cursor | config/keymaps.lua |

## Editing

| Key | Mode | Description | Source |
|-----|------|-------------|--------|
| `<C-s>` | n, i, x, s | Save file | config/keymaps.lua |
| `<A-j>` / `<A-k>` | n, v | Move line/selection down/up | config/keymaps.lua |
| `<` / `>` | v | Indent (keep selection) | config/keymaps.lua |
| `<leader>p` | x | Paste without overwrite | config/keymaps.lua |
| `J` | n | Join lines (preserve cursor) | config/keymaps.lua |
| `<esc>` | n | Clear search highlights | config/keymaps.lua |
| `y` / `p` / `P` | n, x | Yank / put after / put before (Yanky) | yanky |
| `<C-p>` / `<C-n>` | n | Prev/Next yank entry | yanky |
| `<C-a>` / `<C-x>` | n, v | Increment / decrement | dial |
| `gsa` | n, x | Surround add | mini.surround |
| `gsd` | n | Surround delete | mini.surround |
| `gsf` / `gsF` | n | Surround find right/left | mini.surround |
| `gsh` | n | Surround highlight | mini.surround |
| `gsr` | n | Surround replace | mini.surround |
| `gsn` | n | Surround update n lines | mini.surround |
| `<leader>mn` / `<leader>mN` | n, x | Add cursor at next/prev match | multicursor |
| `<leader>ms` / `<leader>mS` | n, x | Skip match next/prev | multicursor |
| `<leader>ma` | n, x | Add cursor at all matches | multicursor |
| `<leader>mj` / `<leader>mk` | n, x | Add cursor on line below/above | multicursor |
| `<leader>mJ` / `<leader>mK` | n, x | Skip line down/up | multicursor |
| `<leader>mx` | n, x | Delete cursor under main | multicursor |
| `<leader>mr` | n | Restore cursors | multicursor |
| `<leader>ml` | n, x | Align cursors to same column | multicursor |
| `<leader>mp` | x | Split visual selection by regex | multicursor |
| `<leader>mt` | x | Transpose text between cursors | multicursor |
| `<C-q>` | n, x | Toggle cursor | multicursor |
| `<C-LeftMouse>` | n | Toggle cursor at click | multicursor |
| `<Tab>` / `<S-Tab>` | n, x | Cycle main cursor (in cursor layer) | multicursor |
| `<Esc>` | n | Clear all cursors (in cursor layer) | multicursor |
| `<leader>Se` | n | Edit snippet | luasnip |
| `<leader>Sa` | n, x | Add snippet | luasnip |
| `q` | n | Start/stop recording | nvim-recorder |
| `Q` | n | Play macro | nvim-recorder |
| `<leader>Qs` | n | Switch macro slot | nvim-recorder |
| `<leader>qe` / `<leader>qy` | n | Edit / yank macro | nvim-recorder |
| `##` | n | Add macro breakpoint | nvim-recorder |
| `<CR>` | i | Accept completion / newline with pair expand | blink.cmp |
| `<C-Space>` | i | Show completion & docs | blink.cmp |

## UI Toggles

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>uf` | n | Toggle format-on-save |
| `<leader>uM` | n | Toggle markdown render |
| `<leader>um` | n | Toggle minimap |
| `<leader>uz` | n | Zen mode |

## Sessions / Quit

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

## Laravel (PHP projects with `artisan`)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ll` | n | Laravel picker |
| `<leader>la` | n | Artisan |
| `<leader>lr` | n | Routes |
| `<leader>lR` | n | Related files |
| `<leader>lm` | n | Make (scaffold) |
| `<leader>lc` | n | Commands |
| `<leader>lo` | n | Resources |
| `<leader>lv` | n | View finder |
| `<leader>lp` | n | Command center |

## REST / HTTP (kulala)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>Rs` | n | Send request |
| `<leader>Ra` | n | Send all requests |
| `<leader>Rb` | n | Open scratchpad |

## Checkmate (Markdown todos)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>tt` | n, v | Toggle todo |
| `<leader>tc` / `<leader>tu` | n, v | Check / uncheck |
| `<leader>t=` / `<leader>t-` | n, v | Cycle next / previous state |
| `<leader>tn` | n, v | New todo |
| `<leader>tx` | n, v | Remove todo marker |
| `<leader>tR` | n, v | Remove all metadata |
| `<leader>ta` | n | Archive completed |
| `<leader>tf` | n | Find todo |
| `<leader>tv` | n | Set metadata value |
| `<leader>t]` / `<leader>t[` | n | Next / prev metadata tag |
| `<leader>tp` / `<leader>ts` / `<leader>td` | n | Insert priority / started / done metadata |

## Which-key groups

`<leader>f` find · `<leader>s` search · `<leader>g` git · `<leader>gh` hunks · `<leader>b` buffer · `<leader>q` quit/session · `<leader>t` todo · `<leader>u` ui · `<leader>x` diagnostics · `<leader>c` code · `<leader>cs` swap · `<leader>d` debug · `<leader>T` test · `<leader>h` harpoon · `<leader>m` multicursor · `<leader>o` overseer · `<leader>r` refactor · `<leader>S` snippets · `<leader>l` laravel · `<leader>R` rest · `g` goto · `gs` surround

## Overlaps to be aware of

- `<leader>sS` — Snacks workspace symbols vs SSR structural replace (last loaded wins).
- `<C-p>` / `<C-n>` — Yanky yank-ring cycling overlaps default completion navigation in insert (blink uses its own keys).
- `q` — nvim-recorder start/stop globally, but buffer-local close-window in help/qf/man.
- `<CR>` — blink.cmp in insert, treesitter incremental-select start in normal, expand selection in visual.
