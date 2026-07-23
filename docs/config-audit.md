# Neovim config audit — 2026-07-23

Traced all 58 Lua files (~9.6k lines) + `lazy-lock.json` (~80 plugins). Headless boot with `GAF=1` is clean, zero errors, nvim 0.12.3. Config is high quality: native `vim.lsp.config`/`vim.lsp.enable`, treesitter `main` branch, `mason-org/*` repos, no deprecated APIs. Findings below are verified first-hand against the source lines cited.

---

## A. Real bugs (worth fixing)

1. **`lua/angular/init.lua:1553-1567` — new import inserted *inside* a multi-line import block.**
   `last_import` is set only on lines matching `^%s*import%s` (1555). For
   ```ts
   import {
     a,
     b
   } from '@x';
   ```
   it points at the `import {` line, so `at = last_import + 1` (1563) inserts the new statement between `import {` and `a,` → broken TS. The *dedup* check (1548) is multiline-safe; the *insertion point* is not. Fix: track brace balance and set `last_import` to the line containing the closing `} from …` of the last import (or insert after the whole import region).

2. **`lua/util/line_history.lua:28` — `git log` runs with no `cwd` but uses a cwd-relative path.**
   `pick_commits` calls `vim.system(cmd, { text = true }, …)` with no `cwd`, while `M.pick`/`M.file` pass `rel = fnamemodify(file, ":.")` and `-L…:rel`. Editing a file outside nvim's cwd → git runs in the wrong repo, `rel` doesn't resolve → empty/wrong history. `blame.lua:56` does this right (`cwd = dir`). Fix: pass `cwd` = the file's dir.

3. **`lua/gaf/xdebug.lua:209-213` and `368-372` — nil-deref in mtime sort comparator.**
   `newest_snapshot`/`newest_trace` do `fs_stat(a).mtime.sec` with no nil guard. A broken symlink, or a `/tmp` file removed between glob and sort, makes `fs_stat` return nil → comparator throws → whole command aborts. Fix: stat once into a table, treat missing stat as oldest.

---

## B. Config conflicts & cleanup

1. **Number-column owner conflict — `ui.lua:286` comfy-line-numbers vs `snacks.lua:25` snacks.statuscolumn.** Both write the global `statuscolumn`. snacks sets it at startup (`lazy=false`), comfy overwrites it on `BufReadPre` → comfy wins, snacks' git/fold rendering in the statuscolumn is dead, and the `foldcolumn="1"` forced in `options.lua:47` (a comment says it exists *for* snacks fold marks) is now serving native marks only. Pick one owner: either drop comfy and keep snacks statuscolumn, or set `snacks … statuscolumn.enabled=false` and let comfy own it. They can't both be on.

2. **`lsp.lua:400-408` lazydev is inert.** It augments `lua_ls`, but `lua_ls` is not in the mason `servers` list (`lsp.lua:13`) and has no `vim.lsp.config` — no Lua LSP runs at all, so editing this very config has no completion/diagnostics. Fix: add `lua_ls` to `servers` + a minimal `vim.lsp.config("lua_ls", {…})`; then lazydev does its job. Otherwise remove lazydev.

3. **`lsp.lua` — capabilities passed per-server ~13×.** `require("blink.cmp").get_lsp_capabilities()` is repeated at 53/60/127/147/157/167/206/217/228/245/261/270/282/294/316 plus `rails.lua:111`, `rust.lua:30`, `flutter.lua:48`. Modern idiom: one global default `vim.lsp.config('*', { capabilities = … })`, per-server tables only override (keep the sourcekit `didChangeWatchedFiles` override as an extend).

4. **`editor.lua:228` dial redundant augend.** `augend.constant.new({ elements = { "true", "false" } })` duplicates `augend.constant.alias.bool` (line 224). Delete 228. (Lines 229-232 `True/False`, `yes/no`, `on/off`, `let/const` are NOT redundant — keep.)

5. **`treesitter.lua:53-54` misleading comment.** Comment says "Enable matchup treesitter integration" but only sets `vim.g.matchup_matchparen_deferred = 1` (defers redraw). On treesitter `main` the old module system is gone, so TS-aware matching is NOT enabled. Fix: set `vim.g.matchup_treesitter = 1` if wanted, else correct the comment.

6. **`formatting.lua:11` vs `rails.lua:199` conform opts — order-dependent.** `formatting.lua`'s `opts = function()` returns a *fresh* table (ignores incoming `opts`); `rails.lua`'s `opts = function(_, opts)` mutates the passed table. Works only because alphabetical import runs `formatting.lua` first; if order ever flips, ruby/eruby formatters silently vanish. Fix: make `formatting.lua` also `function(_, opts)` and merge.

7. **`edgy.lua:8` sets `vim.opt.laststatus = 3`** — already set in `options.lua:37` (its own comment admits it). Dead line, remove.

8. **`editor.lua:63-69` stale comment.** Says `<CR>` inside `{|}` no longer expands — but blink re-implements that expansion at `lsp.lua:452-467`. Comment is now false; update it.

---

## C. Redundancy (optional drops)

- **mini.bufremove → `Snacks.bufdelete`.** 1:1 overlap; only used for `<leader>bd/bD` (`editor.lua:151-154`). snacks already loaded. Drop mini.bufremove, rebind to `Snacks.bufdelete`. (LazyVim already made this switch.)
- **nvim-hlslens** — weakest of the search-position surfacers (flash + satellite already show matches); only adds inline `[n/N]` count. Safe drop candidate if trimming.
- **fff.nvim vs snacks.picker** — deliberate split (fff for big-repo file find, snacks for grep/everything). Keep; noted only for completeness.
- Verified NOT redundant, keep: vim-endwise (ultimate-autopair ships no endwise), ts-comments (no mini.comment installed), satellite (snacks has no gutter scrollbar), noice+snacks.notifier (different jobs — ensure noice `notify.enabled=false` so only snacks toasts).

## D. Maintenance / already-correct

- treesitter family already on `main` branch (0.12-correct). ✓
- `mason-org/*` repos + mason-lspconfig v2 `automatic_enable`. ✓
- nvim-colorizer already on the maintained `catgoose` fork. ✓
- **blink.cmp** — pin `version = '1.*'`; v2 is in-dev with breaking changes.
- nvim-ts-autotag — confirm it's called standalone `require('nvim-ts-autotag').setup()`, not via the removed `nvim-treesitter.configs` path.

---

## E. Plugins worth adding (not installed, 2025-2026, fit this stack)

Ranked by fit to the PHP-monolith / Angular / Rails / Rust / Flutter / Swift + Phabricator + Claude-Code workflow.

**Tier 1**
1. **AI in-editor — pick one.** `folke/sidekick.nvim` (persistent Claude-Code CLI terminal + inline Next-Edit-Suggestion diffs; matches the existing folke stack) or `coder/claudecode.nvim` (MCP/WebSocket bridge — selection + diagnostics into Claude Code, edits land as reviewable diffs). No AI plugin installed today despite living in Claude Code.
2. **`sindrets/diffview.nvim`** — single-tabpage multi-file review across any revision/merge-base + per-file history. fugitive+gitsigns give no review-oriented multi-file diff; real gap for the Phabricator/arcanist review loop.
3. **`stevearc/aerial.nvim`** — LSP/treesitter symbol outline sidebar. No outline installed; invaluable for huge monolith PHP classes and big Angular/TS files. (alt: `hedyhli/outline.nvim`.)
4. **`MeanderingProgrammer/render-markdown.nvim`** — inline markdown rendering; companion to obsidian.nvim + todo-comments, nicer for reading AI output/READMEs/tickets.

**Tier 2 — language gaps**
5. **`saecki/crates.nvim`** — Cargo.toml versions/features/upgrades inline (rustaceanvim covers LSP, not deps).
6. **`vuki656/package-info.nvim`** — npm/pnpm version of the above for the Angular webapp's package.json.
7. **`danymat/neogen`** — treesitter docstring generator: PHPDoc, JSDoc/TSDoc, YARD, rustdoc, Dart — covers 5 of 6 languages.
8. **`dmmulroy/ts-error-translator.nvim`** — plain-English TS diagnostics for the Angular webapp; zero-dep, set-and-forget.

**Tier 3 — editing/nav**
9. **`Wansmer/treesj`** — split/join blocks (args, arrays, objects, hashes) via treesitter, all languages.
10. **`folke/persistence.nvim`** — per-directory session save/restore; useful juggling 6 project types. folke-consistent.
11. **`dnlhc/glance.nvim`** — floating peek-and-edit for definitions/references (trouble is list-view, not inline peek).
12. **`Bekaboo/dropbar.nvim`** — interactive breadcrumb winbar; complements aerial for deep-file orientation.

*Excluded as already-covered or conflicting:* persistent-breakpoints (already installed), symbol-usage.nvim (codelens-style — user keeps codelens off), oil.nvim (overlaps snacks explorer + fff), grapple/telescope/smart-splits/lazygit (covered by harpoon2/snacks/tmux-nav).
