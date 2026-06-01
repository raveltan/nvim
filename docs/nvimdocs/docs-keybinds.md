# docs-keybinds
> Searchable per-prefix keymap table — index of the full keybinds reference.

**Local file:** docs/keybinds.md
**Tags:** keymaps keybinds reference cheatsheet leader prefix index searchable

## Scope

Compressed grep-friendly index of `docs/keybinds.md`. Grouped by leader prefix so you can jump straight to the section you need. Each row links the actual prefix doc when it exists. For full descriptions, source attribution, and overlaps see the canonical cheatsheet.

## How it loads

Reference doc — not loaded by nvim. View with `<leader>fc` → `docs/keybinds.md`.

## Keymaps / Commands — by prefix

### `<leader>a` — Claude Code
| Key | Mode | Action |
|---|---|---|
| `<leader>ac` | n | Toggle Claude Code |
| `<leader>aC` | n | Continue |
| `<leader>ar` | n | Resume |
| `<leader>av` | n | Verbose |

### `<leader>b` — Buffers
| Key | Mode | Action |
|---|---|---|
| `<leader>bo` | n | Close others |
| `<leader>bd` / `bD` | n | Delete buffer / force |
| `<S-h>` / `<S-l>` | n | Prev / next buffer |

### `<leader>c` — Code / LSP
| Key | Mode | Action |
|---|---|---|
| `<leader>ca` | n,v | Code action (preview) |
| `<leader>cA` | n | Source action |
| `<leader>cr` | n | Rename (PHP `$` sigil aware) |
| `<leader>cf` | n | Format file (conform) |
| `<leader>ci` | n | Toggle inlay hints |
| `<leader>cd` | n | Line diagnostics float |
| `<leader>cu` | n | Undo tree |
| `<leader>cj` | n | Split/join (treesj) |
| `<leader>cn` | n | TS node action |
| `<leader>cS` | n,x | Structural search-replace (ssr) |
| `<leader>co`/`cM`/`cU`/`cR`/`cF`/`cD` | n | TS: organize/add missing/remove unused/remove/fix all/source def |
| `<leader>csa`/`csA` | n | Swap arg next/prev |
| `<leader>ce` | n | Emmet expand (in emmet filetypes) |

### `<leader>d` — Debug (DAP)
| Key | Mode | Action |
|---|---|---|
| `<leader>db` / `dB` / `dC` | n | Breakpoint / conditional / clear |
| `<leader>dc` / `di` / `do` / `dO` / `dt` | n | Continue / step into / over / out / terminate |
| `<leader>du` | n | dap-view toggle |
| `<leader>de` | n,v | Watch expression |
| `<leader>dl` | n | Run last |
| `<leader>dd` | n | Better-ts-errors (TS) / Diagram show (md) |
| `<leader>dx` | n | GAF: xdebug start / TS: ts-errors goto-def |
| `<leader>dX` / `dv` / `dD` | n | GAF: xdebug stop / validate / toggle `GAF_DEBUG` |
| `]b` / `[b` | n | Next / prev breakpoint |

### `<leader>D` — Database (dadbod)
| Key | Mode | Action |
|---|---|---|
| `<leader>Du` / `Df` / `Da` / `Dr` / `Dq` | n | UI / find buf / add / rename / last query |

### `<leader>e` — Explorer
| Key | Mode | Action |
|---|---|---|
| `<leader>e` | n | Oil |
| `-` | n | Oil parent |

### `<leader>f` — Find
| Key | Mode | Action |
|---|---|---|
| `<leader>ff` / `<leader><leader>` | n | Files |
| `<leader>,` | n | Buffers |
| `<leader>fr` | n | Recent |
| `<leader>fc` | n | Config files |
| `<leader>fn` | n | New file |
| `<leader>fR` | n | Rename file |

### `<leader>g` — Git
| Key | Mode | Action |
|---|---|---|
| `<leader>gg` | n | Lazygit |
| `<leader>gc` / `gs` | n | Log / status (picker) |
| `<leader>gd` / `gf` | n | Diffview / file history |
| `<leader>gb` / `gB` / `gt` | n | Blame / fugitive blame / virt blame |
| `<leader>g/` | n,v | Git grep / selection |
| `<leader>g*` | n | Git grep word |
| `<leader>go` | n | mini.diff overlay |
| `<leader>gh{s,r,S,R,u,p,d,D}` | n,v | Hunk: stage/reset/buf-stage/buf-reset/undo/preview/diff |
| `]c` / `[c` | n | Next / prev hunk |
| `ih` | o,x | Hunk textobj |

### `<leader>h` — Harpoon
| Key | Mode | Action |
|---|---|---|
| `<leader>ha` | n | Add |
| `<leader>hh` | n | Menu |
| `<leader>1`–`<leader>8` | n | Slot 1–8 |

### `<leader>H` — Hurl (HTTP)
| Key | Mode | Action |
|---|---|---|
| `<leader>H` | v | Run selection |
| `<leader>Ha` / `Hs` / `He` / `Hm` / `Hv` | n | All / cursor / to entry / toggle mode / verbose |

### `<leader>i` — Iron (REPL)
| Key | Mode | Action |
|---|---|---|
| `<leader>is` / `ir` | n | Toggle / restart |
| `<leader>ic` / `iv` / `il` / `if` / `iu` | n,o,x | Send motion/visual/line/file/to-cursor |
| `<leader>im` / `iM` / `id` | n,x | Send mark / mark / remove |
| `<leader>ix` / `iq` / `iC` | n | Interrupt / exit / clear |

### `<leader>m` — Multicursor
| Key | Mode | Action |
|---|---|---|
| `<leader>mn` / `mN` / `ms` / `mS` | n,x | Next/prev/skip-next/skip-prev match |
| `<leader>ma` | n,x | All matches |
| `<leader>mj` / `mk` / `mJ` / `mK` | n,x | Cursor below/above; skip |
| `<leader>mx` / `mr` / `ml` / `mp` / `mt` | n,x | Delete / restore / align / split / transpose |
| `<C-q>` | n,x | Toggle cursor |

### `<leader>n` — AST nav (treewalker)
| Key | Mode | Action |
|---|---|---|
| `<leader>nk` / `nj` / `nh` / `nl` | n,v | Up / down / parent / child |
| `<leader>nK` / `nJ` | n | Swap up / down |

### `<leader>o` — Overseer
| Key | Mode | Action |
|---|---|---|
| `<leader>or` / `oc` | n | Run task / shell cmd |
| `<leader>ol` / `oh` / `ov` / `od` | n | Open task output float / hsplit / vsplit, dispose |
| `<leader>oo` / `os` / `oV` | n | other.nvim related-file pick / split / vsplit |

### `<leader>q` — Quit / Session
| Key | Mode | Action |
|---|---|---|
| `<leader>qq` / `qs` / `qS` / `ql` / `qd` | n | Quit / restore / select / last / don't-save |

### `<leader>r` — Rails
| Key | Mode | Action |
|---|---|---|
| `<leader>rc` / `rg` / `rr` / `rs` / `rm` / `rk` / `rb` / `rC` / `re` | n | Cmds / generate / routes / schema / migrate / rollback / bundle / console / credentials |

### `<leader>R` — Refactor
| Key | Mode | Action |
|---|---|---|
| `<leader>Re` / `Rf` / `Rv` / `Ri` | n,v | Select / extract fn / extract var / inline |

### `<leader>s` — Search
| Key | Mode | Action |
|---|---|---|
| `<leader>sg` | n | Live grep |
| `<leader>sw` | n,x | Word / selection |
| `<leader>sb` / `sh` / `sk` / `sc` / `sd` | n | Buffer lines / help / keymaps / commands / diagnostics |
| `<leader>ss` / `sS` | n | Document / workspace symbols |
| `<leader>sj` / `sm` / `s/` / `s:` / `s.` / `st` | n | Jumplist / marks / search hist / cmd hist / cwd grep / todos |
| `<leader>sr` | n | grug-far |
| `<leader>sR` | n,x | Resume picker / grug-far cword|sel |
| `<leader>su` | n | Undo history |
| `gw` | n | Grep cword |

### `<leader>S` — Snippets
| Key | Mode | Action |
|---|---|---|
| `<leader>Se` / `Sa` | n,x | Edit / add (scissors) |

### `<leader>t` — Tests (Neotest) / Checkmate in markdown / GAF extras
| Key | Mode | Action |
|---|---|---|
| `<leader>tr` / `tf` / `tl` / `ts` / `to` / `tO` / `td` / `tS` / `tC` | n | Nearest / file / last / summary / output / panel / debug / stop / coverage |
| **GAF:** `<leader>tx` / `tX` | n | bin/run-tests setup / shutdown |
| **GAF:** `<leader>tp` / `tP` | n | Profile run / replay |
| **GAF:** `<leader>tm` / `tw` | n | UI test mobile / watch |
| **Markdown (Checkmate):** `<leader>tt` / `tc` / `tu` / `t=` / `t-` / `tn` / `tx` / `tR` / `ta` / `tf` / `tv` / `t]` / `t[` / `tp` / `ts` / `td` | n,v | Toggle/check/uncheck/cycle/new/remove/archive/find/metadata |

### `<leader>u` — UI toggles
| Key | Mode | Action |
|---|---|---|
| `<leader>uf` / `ud` / `uM` / `uz` | n | Format-on-save / diagnostics / markdown render / zen |

### `<leader>w` — Window
| Key | Mode | Action |
|---|---|---|
| `<leader>\|` / `-` | n | Vsplit / hsplit |
| `<leader>wr` | n | Resize submode |
| `<C-Up>`/`Down`/`Left`/`Right` | n | Resize |

### `<leader>x` — Diagnostics / lists
| Key | Mode | Action |
|---|---|---|
| `<leader>xx` / `xq` / `xQ` / `xl` | n | Trouble / qf / quicker / loclist |

### `g*` — Goto / surround / misc
| Key | Mode | Action |
|---|---|---|
| `gd` / `gr` / `gI` / `gy` | n | Defn / refs / impls / types (snacks) |
| `gD` / `gR` / `gY` / `gM` | n | Peek (glance) |
| `gx` | n | URL/file/Phab `D####`/`T####` |
| `gw` | n | Grep cword |
| `gsa` / `gsd` / `gsr` / `gsf` / `gsF` / `gsh` / `gsn` | n,x | Surround |
| `]r` / `[r` | n | LSP ref cycle (refjump) |
| `]]` / `[[` | n | Reference (illuminate) |
| `]d` / `[d` / `]e` / `[e` / `]w` / `[w` | n | Diagnostic / error / warning |
| `]f` / `[f` / `]a` / `[a` | n,x,o | Function / arg textobj nav |

### `cr*` — vim-abolish case coercion
| Key | Result on `myVar` |
|---|---|
| `crs` / `crc` / `crm` / `cru` / `cr-` / `cr.` / `crt` | snake / camel / Pascal / UPPER / kebab / dot / Title |

### `<C-*>` — control
| Key | Mode | Action |
|---|---|---|
| `<C-s>` | n,i,x,s | Save |
| `<C-h/j/k/l>` | n | Window/tmux nav |
| `<C-o>` / `<C-i>` | n | Jumplist (Jumppack preview) |
| `<C-d>` / `<C-u>` | n | Half-page centered |
| `<C-a>` / `<C-x>` | n,v | Inc / dec (dial) |
| `<C-p>` / `<C-n>` | n | Yank ring prev / next |
| `<C-q>` | n,x | Multicursor toggle |
| `<C-Space>` | i | blink.cmp menu |
| `<esc><esc>` | t | Exit terminal mode |

### `<C-y>*` — Emmet (html/eruby/css/jsx/tsx/vue/svelte)
| Key | Action |
|---|---|
| `<C-y>,` / `;` | Expand / expand inline |
| `<C-y>u` / `d` / `D` / `n` / `N` / `i` / `m` / `k` / `j` / `/` / `a` / `A` | Update / balance in / out / next / prev / image size / merge / remove / split-join / comment / anchor / quote |

### Filetype tricks (after/ftplugin)
| Trigger | FT | Result |
|---|---|---|
| `$$` (insert) | php | `$this->` (skips after word/$) |
| `fn<Tab>` | php | `fn($x) => ` arrow fn |

## Links

- Canonical: `docs/keybinds.md` (full table with source attribution)
- [editor-which-key](editor-which-key.md) — group labels
- [gaf-readme](gaf-readme.md) — GAF-specific workflow
- [gaf-dap](gaf-dap.md) / [gaf-test](gaf-test.md) — GAF prefix details

## Notes

- Leader = `<space>`, localleader = `\`.
- Checkmate owns `<leader>t*` **only in markdown buffers** — neotest keys work everywhere else.
- `<leader>sR` overlaps snacks-resume and grug-far-cword — last-loaded wins.
- `<leader>dd` is filetype-scoped: ts-errors (TS) vs diagram (md/norg).
