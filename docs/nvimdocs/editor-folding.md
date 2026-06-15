# editor-folding
> Native treesitter folding (`vim.treesitter.foldexpr`) rendered through the snacks statuscolumn — no plugin.

**Repo:** core Neovim (no plugin) + [ts-nvim-treesitter](ts-nvim-treesitter.md) `folds.scm` queries
**Local spec:** lua/config/options.lua (fold opts), lua/plugins/treesitter.lua:33-44 (per-buffer foldexpr), lua/config/foldtext.lua (foldtext)
**Tags:** folding, treesitter, core, ui

## Scope

Folding is wired entirely from core Neovim 0.12 — no `nvim-ufo`, no `nvim-treesitter` fold module (the `main` branch rewrite removed it). Each buffer with a treesitter parser gets `foldmethod=expr` + `foldexpr=v:lua.vim.treesitter.foldexpr()`, which computes fold levels from the parser's `folds.scm` `@fold` captures. Buffers without a parser keep the default `foldmethod=manual`. Fold marks render in the [snacks-core](snacks-core.md) statuscolumn.

## Install spec

No install. Requirements already met by this config:

- **Neovim 0.12+** — ships `vim.treesitter.foldexpr()`. (Note: `vim.treesitter.foldtext()` does **not** exist in 0.12 — see Notes.)
- **nvim-treesitter `main`** — installs `queries/<lang>/folds.scm` for the parsers listed in [ts-nvim-treesitter](ts-nvim-treesitter.md). The `main` branch does NOT auto-enable folds; this config wires them in the treesitter `FileType` autocmd.
- **snacks statuscolumn** — `statuscolumn = { enabled = true }` in lua/plugins/snacks.lua draws the fold column.

## Common customizations

Set in lua/config/options.lua:

- `foldlevel` / `foldlevelstart` *(99)* — start fully unfolded; avoids "everything collapsed on open."
- `foldnestmax` *(4)* — cap fold depth.
- `foldcolumn` *("1")* — **required** for snacks to render fold marks (it gates on `foldcolumn ~= "0"`).
- `foldenable` *(true)* — folds allowed; `za`/`zc`/`zo` work.
- `fillchars.foldopen` / `foldclose` / `foldsep` — glyphs snacks reads for the fold-column arrows.
- `foldtext` — custom fn (lua/config/foldtext.lua). Set to `""` instead if you prefer the fold's first line rendered with full per-token treesitter highlighting and no line count.
- `foldopen` *(default)* — which motions auto-open a fold when you land in it.

## Our config

- `foldmethod`/`foldexpr` are **not** global — they're set window-local + buffer-scoped (`vim.wo[0][0]`) inside the existing `treesitter_highlight` `FileType` autocmd (lua/plugins/treesitter.lua), right beside `indentexpr`. This means folds turn on **only** where `vim.treesitter.start()` succeeded — so the same `TS_MAX_BYTES` (500KB) / `TS_MAX_LINES` (10000) guard that skips highlight/indent also skips folding on huge buffers, which stay on cheap manual folds.
- `foldlevel=99` is re-asserted inside the autocmd because folds enable *after* the window is already displayed; without the re-assert the buffer can appear collapsed.
- `foldtext` uses a custom function (lua/config/foldtext.lua) showing the first line + `󰁂 N lines` count.
- **Why native over nvim-ufo:** ufo would only add a folded-line count badge (we get that from our foldtext) and a peek window, while duplicating the fold column snacks already draws and forcing `foldmethod=manual` globally — a real conflict. Native is two lines, zero dependencies, and inherits the large-buffer guard for free. See `editor-ufo.md` history if you want the rejected design.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `za` | n | built-in | Toggle fold under cursor |
| `zo` / `zc` | n | built-in | Open / close fold under cursor |
| `zR` / `zM` | n | built-in | Open / close all folds |
| `zr` / `zm` | n | built-in | Reduce / increase fold level by one |
| `zj` / `zk` | n | built-in | Jump to next / prev fold |
| `zx` | n | built-in | Recompute folds (update + reapply foldexpr) |

Folding is all built-ins now — native `foldexpr` can leave stale fold boundaries after rapid edits (neovim#26224); the built-in `zx` forces a recompute. (The former `<leader>zx` alias was removed — just use `zx`.)

## Links

- `:help vim.treesitter.foldexpr()` — https://neovim.io/doc/user/treesitter.html
- `:help 'foldtext'` (empty-string behavior) — https://neovim.io/doc/user/options.html
- nvim-treesitter main folding — https://github.com/nvim-treesitter/nvim-treesitter
- snacks statuscolumn — https://github.com/folke/snacks.nvim/blob/main/docs/statuscolumn.md

## Notes

- **`vim.treesitter.foldtext()` is `nil` in 0.12.2** (verified). Do not set `foldtext='v:lua.vim.treesitter.foldtext()'` — it errors. Use `foldtext=""` or the custom fn.
- snacks draws fold marks only when `vim.wo[win].foldcolumn ~= "0"` (`fold_info()` FFI check). With no `foldcolumn` set, folds work but show no arrows — `foldcolumn="1"` is mandatory.
- snacks hides the open-fold (down) chevron by default (`folds.open = false`); set `statuscolumn = { folds = { open = true } }` in snacks.lua to show it.
- Fold computation is async since 0.11 — fold levels can be briefly stale right after opening a file until the parse finishes. Cosmetic, self-corrects; the built-in `zx` forces it.
- Cross-links: [ts-nvim-treesitter](ts-nvim-treesitter.md), [snacks-core](snacks-core.md), [config-options](config-options.md).
