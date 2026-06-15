# editor-folding
> Folding driven by [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo) — LSP `foldingRange` folds with a treesitter fallback, a peek window, and a syntax-highlighted foldtext. Marks render through the snacks statuscolumn.

**Repo:** [kevinhwang91/nvim-ufo](https://github.com/kevinhwang91/nvim-ufo) (+ `kevinhwang91/promise-async`)
**Local spec:** lua/plugins/fold.lua (ufo setup + keymaps), lua/config/options.lua (fold opts), lua/plugins/lsp.lua (`foldingRange` capability), lua/config/foldtext.lua (fallback foldtext)
**Tags:** folding, ufo, lsp, treesitter, ui

## Scope

nvim-ufo owns folding. It sets `foldmethod=manual` per buffer and applies folds it computes from its providers, so the old `foldmethod=expr` / `vim.treesitter.foldexpr()` wiring was **removed** from the treesitter `FileType` autocmd (the two cannot coexist — expr folding fights ufo's manual folds). Treesitter still matters: it is ufo's *fallback fold provider*, using the same parsers / `folds.scm` queries listed in [ts-nvim-treesitter](ts-nvim-treesitter.md). Fold marks render in the [snacks-core](snacks-core.md) statuscolumn.

Provider chain (lua/plugins/fold.lua `provider_selector`): `{ "lsp", "treesitter" }` — LSP folds first, treesitter when the server gives nothing. Disabled (returns `""`) for special buffers (`buftype ~= ""`) and buffers over 10000 lines, mirroring the treesitter perf guard so huge/generated files stay cheap.

## Install spec

Managed by lazy.nvim (lua/plugins/fold.lua). Requirements:

- **nvim-ufo** + **promise-async** — auto-installed; loads on `BufReadPost` / `BufNewFile`.
- **LSP `foldingRange` capability** — advertised in lua/plugins/lsp.lua so servers (intelephense, basedpyright, jsonls, yamlls, …) return semantic fold ranges. Without it ufo silently falls back to treesitter.
  ```lua
  capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
  ```
- **Baseline fold opts** (lua/config/options.lua) — `foldenable=true`, `foldlevel=99`, `foldlevelstart=2`, `foldcolumn="1"`. `foldlevel=99` is the max; `foldlevelstart=2` means buffers **open folded to level 2** (top-level + one nesting open, deeper bodies closed). `zR` opens all.
- **snacks statuscolumn** — `statuscolumn = { enabled = true }` in lua/plugins/snacks.lua draws the fold column (gates on `foldcolumn ~= "0"`).

## What ufo adds over native treesitter folds

- **Semantic LSP folds** — import blocks, `#region`/`#endregion`, multiline comments fold as units the treesitter `folds.scm` query misses.
- **Peek window** (`zp`) — preview a closed fold's body in a float without opening it. `q` closes, `<C-d>`/`<C-u>` scroll, `[`/`]` jump top/bottom.
- **Fold-to-level** (`z1`..`z5`) — set an absolute `foldlevel`; works on ufo's manual folds (e.g. `z1` inside a class folds every method body but keeps the class open).
- **Highlighted foldtext** — first line keeps real per-token highlights + a `󰁂 N lines` count (ufo `fold_virt_text_handler`, styled to match the old custom foldtext).

## Our config

- **Open level on load** is set by `foldlevelstart=2` (lua/config/options.lua), not by ufo. To open everything instead, set it to `99`; to fold tighter, lower it. `close_fold_kinds_for_ft` is left unset — to also auto-fold imports regardless of level, add `close_fold_kinds_for_ft = { default = { "imports" } }` to the ufo opts.
- **foldtext** — ufo's `fold_virt_text_handler` replaces `'foldtext'` per ufo-managed buffer. The custom lua/config/foldtext.lua + `opt.foldtext` remain only as a fallback for buffers ufo doesn't manage.
- `foldnestmax` was **removed** — it only affects expr/indent folding, a no-op under ufo's manual folds.

## Keymaps

| Key | Mode | Source | Desc |
|-----|------|--------|------|
| `za` | n | built-in | Toggle fold under cursor |
| `zo` / `zc` | n | built-in | Open / close fold under cursor |
| `zR` / `zM` | n | ufo | Open / close all folds |
| `zr` / `zm` | n | ufo | Raise / lower fold level by one |
| `z1`..`z5` | n | fold.lua | Fold to level N (`foldlevel = N`) |
| `]z` / `[z` | n | ufo | Jump to next / prev **closed** fold |
| `zj` / `zk` | n | built-in | Jump to next / prev fold start/end |
| `zp` | n | ufo | Peek folded lines under cursor |

Note: `]z`/`[z` were the built-in "move to fold edge" motions — remapped here to jump between *closed* folds (ufo `goNextClosedFold`/`goPreviousClosedFold`).

## Links

- nvim-ufo — https://github.com/kevinhwang91/nvim-ufo
- nvim-ufo API/options — https://github.com/kevinhwang91/nvim-ufo#minimal-configuration
- `:help vim.lsp.protocol` (foldingRange capability) — https://neovim.io/doc/user/lsp.html
- snacks statuscolumn — https://github.com/folke/snacks.nvim/blob/main/docs/statuscolumn.md

## Notes

- `lineFoldingOnly = true` — ufo folds whole lines, not character ranges; required for the LSP provider to behave.
- snacks draws fold marks only when `vim.wo[win].foldcolumn ~= "0"` (`fold_info()` FFI check) — `foldcolumn="1"` is mandatory.
- snacks hides the open-fold (down) chevron by default (`folds.open = false`); set `statuscolumn = { folds = { open = true } }` in snacks.lua to show it.
- ufo recomputes folds on buffer changes; the old native `zx` recompute workaround (neovim#26224) is no longer needed.
- Cross-links: [ts-nvim-treesitter](ts-nvim-treesitter.md), [snacks-core](snacks-core.md), [config-options](config-options.md), [lsp-config](lsp-config.md).
