# Neovim Configuration

A modular, LSP-first Neovim configuration built on [lazy.nvim](https://github.com/folke/lazy.nvim). Optimized for polyglot development across TypeScript/Angular, PHP, Ruby on Rails, and Python. Ships an opt-in GAF profile (`GAF=1 nvim`) that layers Freelancer-specific tooling (`fl-gaf` monorepo, Phabricator, xdebug remote debugging) on top of the base config — see [GAF Profile](#gaf-profile).

> Looking for the keybind cheatsheet? See [`docs/keybinds.md`](docs/keybinds.md).

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Layout](#layout)
- [Bootstrap Flow](#bootstrap-flow)
- [GAF Profile](#gaf-profile)
- [Core Options](#core-options)
- [Keymap Conventions](#keymap-conventions)
- [Plugins by Category](#plugins-by-category)
- [How to Add Things](#how-to-add-things)
- [How to Configure Things](#how-to-configure-things)
- [Support Files](#support-files)
- [Snippets](#snippets)
- [Multicursor](#multicursor)
- [Debugging (PHP / xdebug + DAP)](#debugging-php--xdebug--dap)
- [Troubleshooting](#troubleshooting)

---

## Requirements

**Core**
- Neovim ≥ 0.11 (uses `vim.lsp.config`, `vim.lsp.enable`, `vim.diagnostic.config` API)
- Git
- A Nerd Font (icons via `mini.icons`)
- `ripgrep` and `fd` (used by Snacks pickers)
- `make`, a C compiler (treesitter parsers)

**Optional but recommended**
- [Kitty](https://sw.kovidgoyal.net/kitty/) terminal — required for inline diagram rendering (`diagram.nvim`)
- `lazygit` — for `<leader>gg`
- `tmux` with `vim-tmux-navigator` — seamless `<C-h/j/k/l>` between splits and panes
- `node` + `npm` — drives Mason-installed JS-based language servers
- Language toolchains as needed: `ruby`, `bundler`, `php`, `composer`, `python3`, `pipx`

**Language tools auto-installed via Mason**
- LSPs: `eslint`, `basedpyright`, `ruff`, `intelephense`, `jsonls`, `yamlls`, `tailwindcss`, `html`, `cssls`
- DAP adapters: `debugpy` (Python), `vscode-php-debug` (PHP)

**Tools you must install yourself**
- `stylua`, `prettierd` / `prettier`, `php-cs-fixer` (formatters)
- `phpcs`, `phpstan` (linters — GAF monorepo only)
- `rubocop` (gem), `erb-formatter` gem (provides `erb_format`), `@herb-tools/language-server` (npm) for Rails ERB
- `stimulus-language-server` (npm, optional) — Hotwire Stimulus LSP; auto-enabled when on `$PATH`
- `debug` gem (Ruby ≥3.1 bundles it) — for nvim-dap-ruby. Run app with `RUBY_DEBUG_OPEN=true`
- `simplecov` gem (optional) — produces `coverage/.resultset.json` for `nvim-coverage`
- `mmdc`, `d2`, `plantuml`, `gnuplot`, `imagemagick` (diagram rendering, optional)

---

## Installation

```sh
git clone <this-repo> ~/.config/nvim
nvim
```

On first launch, lazy.nvim bootstraps itself, installs all plugins from `lua/plugins/*.lua`, and triggers Mason to fetch language servers. Restart once installs complete.

Lockfile: [`lazy-lock.json`](lazy-lock.json) pins **~112 plugins**. Use `:Lazy sync` to update; commit the lockfile after.

---

## Layout

```
.
├── init.lua                      # Entry point — loads four config modules in order
├── lazy-lock.json                # Pinned plugin versions (commit this)
├── lua/
│   ├── config/
│   │   ├── options.lua           # vim.opt settings, leader keys, providers
│   │   ├── lazy.lua              # lazy.nvim bootstrap + plugin spec import
│   │   ├── keymaps.lua           # Global keymaps (no plugin keymaps here)
│   │   ├── autocmds.lua          # Autocmd groups + LSP hover workaround
│   │   └── neotest-coverage.lua  # PHP/Ruby neotest run-with-coverage helper
│   ├── gaf/                      # GAF profile (loaded only when GAF=1)
│   │   ├── init.lua              # Bootstrap — wires commands + keymaps
│   │   ├── paths.lua             # ~/freelancer-dev/fl-gaf, devbox name, /mnt/gaf
│   │   ├── xdebug.lua            # bin/gaf-xdebug wrapper + profile picker
│   │   ├── dap.lua               # PHP xdebug DAP config + GAF keymaps
│   │   ├── lsp.lua               # Mason filter + basedpyright extraPaths
│   │   ├── formatting.lua        # php-cs-fixer + phpcs config
│   │   ├── test.lua              # neotest extension (ui-tests adapter, GAF keys)
│   │   ├── test_infra.lua        # bin/run-tests setup/shutdown
│   │   ├── neotest-profile.lua   # Run a test with XDEBUG_MODE=profile
│   │   ├── neotest-ui-tests.lua  # Custom adapter for webapp UI specs
│   │   ├── ui_test.lua           # Helper for UI test overseer templates
│   │   └── keymaps.lua           # Phabricator D####/T#### gx opener
│   ├── plugins/                  # One file per category — lazy auto-imports all
│   │   ├── editor.lua            # Editing UX (flash, surround, multicursor, ...)
│   │   ├── formatting.lua        # conform.nvim + nvim-lint
│   │   ├── lsp.lua               # Mason, lspconfig, blink.cmp, trouble
│   │   ├── nav.lua               # oil, harpoon, jumppack, glance, tmux-navigator
│   │   ├── ui.lua                # rose-pine, lualine, noice, zen-mode
│   │   ├── snacks.lua            # snacks.nvim (picker, dashboard, terminal, ...)
│   │   ├── treesitter.lua        # parsers, textobjects, context, autotag
│   │   ├── productivity.lua      # typescript-tools, dadbod, iron, satellite
│   │   ├── workflow.lua          # overseer, persistence, claude-code
│   │   ├── dap.lua               # Debugger
│   │   ├── git.lua               # gitsigns, diffview, git-conflict
│   │   ├── test.lua              # neotest + adapters
│   │   ├── ror.lua               # Rails-specific
│   │   ├── other.lua             # other.nvim — related-file navigation
│   │   └── diagram.lua           # mermaid/d2/plantuml inline render
│   └── overseer/template/user/   # Custom overseer task templates (auto-discovered)
├── after/ftplugin/               # Per-filetype tricks (e.g. PHP `$$` → `$this->`)
├── snippets/                     # LuaSnip vscode-format JSON (ts/php/ruby/eruby)
├── scripts/neotest-run-tests.sh  # PHPUnit wrapper for fl-gaf Docker test infra
└── docs/keybinds.md              # 150+ keybind cheatsheet
```

---

## Bootstrap Flow

`init.lua` loads four modules in strict order:

```lua
require("config.options")    -- 1. vim.opt + leader keys (must run before plugins)
require("config.lazy")       -- 2. lazy.nvim bootstrap + import "plugins" dir
require("config.keymaps")    -- 3. Global keymaps (after plugins so picker fns exist)
require("config.autocmds")   -- 4. Autocmds + LSP hover patch
```

`config/lazy.lua`:
- Auto-clones `lazy.nvim` to `~/.local/share/nvim/lazy/` if missing
- `spec = { { import = "plugins" } }` — every `.lua` file under `lua/plugins/` is loaded as a plugin spec module
- Default colorscheme: `rose-pine` (falls back to `habamax`)
- Auto-update checker: enabled, silent
- Disables built-in plugins: `gzip`, `tarPlugin`, `zipPlugin`, `tohtml`, `tutor`

---

## GAF Profile

Freelancer-specific tooling is opt-in via an environment flag. Run vanilla Neovim with `nvim`, or layer the GAF profile on top with:

```sh
GAF=1 nvim
# or alias it permanently:
alias gnvim='GAF=1 nvim'
```

`init.lua` reads `vim.env.GAF` once and sets `vim.g.gaf`. Every GAF feature is gated on that flag, so non-GAF use of this config never pulls in `~/freelancer-dev`, `fl-gaf` Docker test scripts, Phabricator URLs, or the xdebug helpers.

### What the flag turns on

| Feature | Module | Surface |
|---|---|---|
| `:GafXdebug*` commands + `<leader>dx/dX/dv` keys | `lua/gaf/xdebug.lua` | Port-forward, validate, profile snapshot management |
| PHP DAP `Listen for Xdebug (:9003)` + `/mnt/gaf` path map | `lua/gaf/dap.lua` | Remote debugging via `vscode-php-debug` |
| Custom `neotest-ui-tests` adapter | `lua/gaf/neotest-ui-tests.lua` | `yarn ui:<project>` for `webapp/projects/*/ui-tests/src/*.spec.ts` |
| neotest phpunit → `scripts/neotest-run-tests.sh` wrapper | `lua/gaf/test.lua` | Routes through `bin/run-tests` Docker infra |
| `<leader>tx/tX` setup / shutdown test infra | `lua/gaf/test_infra.lua` | Wraps `bin/run-tests setup`/`shutdown` |
| `<leader>tp/tP` + `<leader>dD` profile / debug toggles | `lua/gaf/test.lua` | Per-buffer PHP keys; `GAF_DEBUG=1` env |
| `<leader>tm/tw` mobile / watch flags | `lua/gaf/test.lua` | Active on `*/ui-tests/src/*.spec.ts` buffers |
| `phpcs` linter on save + `php-cs-fixer` formatter | `lua/gaf/formatting.lua` | Uses `fl-gaf/phpcs_gaf.xml`, `fl-gaf/.php-cs-fixer.dist.php` |
| `basedpyright` extraPaths (`libgafthrift`, `restutils`) | `lua/gaf/lsp.lua` | Python type-resolution for GAF Thrift libs |
| `tailwindcss` LSP **disabled** | `lua/gaf/lsp.lua` | Removed from `mason-lspconfig` ensure_installed |
| `gx` on `D####` / `T####` opens Phabricator | `lua/gaf/keymaps.lua` | Falls through to `vim.ui.open(<cfile>)` otherwise |
| Overseer `ui_test_*` + `fli provision` templates | `lua/overseer/template/user/*.lua` | `condition.callback` returns `vim.g.gaf and has_webapp()` |
| `~/freelancer-dev` in Snacks project picker | `lua/plugins/snacks.lua` | Added to `dev` paths |

### How to add a GAF-only feature

1. Drop a module under `lua/gaf/` (e.g. `lua/gaf/myfeature.lua`).
2. Wire it from the relevant base file with a one-line hook:
   ```lua
   if vim.g.gaf then require("gaf.myfeature").setup() end
   ```
   Or, for global side effects, register it in `lua/gaf/init.lua`'s `setup()`.
3. Constants belong in `lua/gaf/paths.lua` — never inline `~/freelancer-dev` elsewhere.

### Disabling the profile temporarily

`unset GAF` before launching, or simply use `nvim` instead of the alias. No state survives between launches — `vim.g.gaf` is recomputed every start.

---

## Core Options

Defined in [`lua/config/options.lua`](lua/config/options.lua).

| Setting | Value | Notes |
|---|---|---|
| Leader | `<space>` | `mapleader = " "` |
| Local leader | `\` | `maplocalleader = "\\"` |
| Indent | 2 spaces, expandtab | Smartindent **disabled** (treesitter/indentexpr handles it) |
| Line numbers | absolute + relative | Hybrid mode |
| Clipboard | `unnamedplus` | System clipboard sync |
| Undo | persistent (file-based) | Survives sessions |
| Search | `ignorecase` + `smartcase` + `inccommand` | Live `:s` preview |
| Folds | enabled, high default level | nvim-ufo handles UI |
| Statusline | global (`laststatus = 3`) | One bar across splits |
| Window borders | rounded | Float style |
| Scroll | `smoothscroll`, `scrolloff = 8` | |
| Diff | vertical splits | |
| Jumpoptions | `view` | Preserves scroll position on jump |

---

## Keymap Conventions

Leader-prefixed groups (registered with `which-key`):

| Prefix | Group | Examples |
|---|---|---|
| `<leader>b` | **B**uffers | `bo` close others |
| `<leader>c` | **C**ode / LSP | `ca` action, `cr` rename, `cf` format, `cn` TS node action, `cS` SSR, `cj` split/join, `co` organize imports (TS) |
| `<leader>d` | **D**ebug (DAP) | `db` breakpoint, `dc` continue, `du` UI (dap-view), `de` watch |
| `<leader>D` | **D**adbod (DB) | `Du` UI, `Df` find buffer, `Dq` last query |
| `<leader>e` | **E**xplorer | `e` open oil |
| `<leader>f` | **F**ind | `ff` files, `fr` recent, `fc` config, `fn` new file, `fR` rename |
| `<leader>g` | **G**it | `gg` lazygit, `gd` diffview, `gb` blame, `gh*` hunk ops, `go` mini.diff overlay |
| `<leader>h` | **H**arpoon | `ha` add, `hh` toggle, `<leader>1`–`<leader>8` slot jump |
| `<leader>H` | **H**url (REST) | `Ha` run all, `Hs` at cursor |
| `<leader>i` | **I**ron (REPL) | `is` toggle, `ic` send motion, `iv` send visual |
| `<leader>m` | **M**ulticursor | `mn` next, `ma` all matches |
| `<leader>n` | Tree**w**alker | `nk/nj/nh/nl` AST up/down/parent/child |
| `<leader>o` | **O**verseer | `or` run, `oc` shell command, `ot` toggle list |
| `<leader>q` | **Q**uit / Session | `qq` quit all, `qs` restore session |
| `<leader>r` | **R**ails | `rc` commands palette, `rg` generate, `rr` routes, `rs` schema, `rm` migrate, `rk` rollback, `rb` bundle install, `rC` console, `re` credentials:edit |
| `<leader>R` | **R**efactor | `Re` extract function, `Rv` extract var |
| `<leader>s` | **S**earch | `sg` grep, `sw` grep word, `ss` symbols, `sr` find/replace, `su` undo history |
| `<leader>S` | **S**nippets | `Se` edit, `Sa` add |
| `<leader>t` | **T**ests / Checkmate | `tr` nearest, `tf` file, `td` debug, `ts` summary (Checkmate owns `<leader>t*` in markdown) |
| `<leader>u` | **U**I toggles | `uz` zen, `ud` diagnostics, `uf` format-on-save, `uM` markdown render |
| `<leader>x` | Diagnostics / lists | `xx` trouble, `xq` quickfix, `xl` loclist |
| `<leader>a` | Cl**a**ude Code | `ac` toggle, `aC` continue, `ar` resume |

Other notable global keymaps (from `config/keymaps.lua`):

- `<C-h/j/k/l>` — split + tmux pane navigation
- `<C-o>` / `<C-i>` — jumplist back/forward (Jumppack floating preview)
- `<leader>;` — dropbar breadcrumb picker (h=parent, l=child)
- `<S-h>` / `<S-l>` — previous / next buffer
- `<A-j>` / `<A-k>` — move line(s) down / up (works in visual)
- `<C-s>` — save (n/i/v/s)
- `gw` — grep word under cursor (Snacks)
- `gx` — open URL/file under cursor. Under GAF profile, also detects Phabricator `D####`/`T####` tokens.
- `n` / `N` — search next/prev with hlslens count + recenter
- `<C-d>` / `<C-u>` — half-page scroll, cursor recentered
- `<Esc><Esc>` — exit terminal mode

Full reference: [`docs/keybinds.md`](docs/keybinds.md).

### Filetype tricks (`after/ftplugin/`)

- **PHP `$$` → `$this->`** — insert-mode expansion. Skips when previous char is word/`$` so `$$foo` stays literal. See `after/ftplugin/php.lua`.

### vim-abolish case coercion (`cr` prefix)

Operate on word under cursor. Memorize once, use across PHP (snake), TS (camel), Ruby (snake), Angular (kebab).

| Key | `myVar` → | |
|---|---|---|
| `crs` | `my_var` | snake |
| `crc` | `myVar` | camel |
| `crm` | `MyVar` | mixed/pascal |
| `cru` | `MY_VAR` | upper |
| `cr-` | `my-var` | kebab |
| `cr.` | `my.var` | dot |

Multi-form replace: `:%S/facilit{y,ies}/building{,s}/g` rewrites singular + plural together.

---

## Plugins by Category

### Editing UX — `editor.lua`
`vim-sleuth`, `nvim-ufo`, `undotree`, `treesj`, `ts-node-action`, `ssr.nvim` (structural replace `<leader>cS`), `refactoring.nvim`, `ultimate-autopair`, `mini.surround` (`gs` prefix), `grug-far` (search/replace), `flash.nvim` (`s`/`S` jumps), `markview.nvim`, `todo-comments`, `mini.bufremove`, `mini.ai`, `yanky` (100-entry yank ring), `multicursor.nvim`, `hurl.nvim`, `nvim-bqf`, `quicker.nvim` (editable qf), `nvim-hlslens`, `highlight-undo`, `dial.nvim`, `ts-comments`, `vim-matchup`, `nvim-scissors`, `marks.nvim`, `which-key`, `checkmate.nvim`, `vim-repeat`, `vim-abolish`, `vim-illuminate`, `refjump.nvim` (`]r`/`[r` LSP refs), `dropbar.nvim` (winbar breadcrumbs, `<leader>;`).

### LSP & Completion — `lsp.lua`
- **Mason** + **mason-lspconfig** auto-install: `eslint`, `basedpyright`, `ruff`, `intelephense`, `jsonls`, `yamlls`, `tailwindcss`, `html`, `cssls`
- **TypeScript** is handled by `typescript-tools.nvim` in `productivity.lua` (faster than `ts_ls`)
- **blink.cmp** — completion (sources: `lsp` → `path` → `snippets` → `buffer`, max 50 LSP items, prefer-rust fuzzy)
- **fidget.nvim** — LSP progress
- **trouble.nvim** — diagnostics panel (`<leader>xx`)
- **actions-preview.nvim** — code action diff preview (`<leader>ca`); rename uses raw `textDocument/rename` (`<leader>cr`, handles PHP `$` sigil)
- **lazydev.nvim** — Lua LSP awareness for `vim.*` API
- Diagnostics: `virtual_text` off (handled by `tiny-inline-diagnostic`); custom signs `✘ ⚠ ℹ ⚡`

### Formatting & Linting — `formatting.lua`
- `conform.nvim`: `stylua` (Lua), `prettierd`/`prettier` (JS/TS), `ruff_organize_imports` + `ruff_format` (Python). PHP `php-cs-fixer` added by [GAF profile](#gaf-profile).
- `nvim-lint`: empty by default. GAF profile registers `phpcs` against `phpcs_gaf.xml`.
- Format-on-save: enabled (3s timeout, LSP fallback). Toggle with `<leader>uf`.
- **TS auto-organize on save** (`productivity.lua`): adds missing + removes unused imports synchronously on `BufWritePre` for `*.ts/tsx/js/jsx`. Notifies "TS: organizing imports…". Disable per-session via `:let g:disable_ts_organize_on_save = 1`.

### Navigation — `nav.lua`
`vim-tmux-navigator`, `oil.nvim` (file explorer with hidden files), `harpoon2` (`<leader>1`–`<leader>8` slot jump, 8 marks), `Jumppack.nvim`, `glance.nvim` (`gD`/`gR`/`gY`/`gM` peek).

### UI — `ui.lua`
`rose-pine` (main variant, transparent backgrounds), `mini.icons`, `lualine.nvim`, `rainbow-delimiters`, `nvim-colorizer.lua`, `tiny-inline-diagnostic` (powerline preset), `zen-mode.nvim` (120 cols), `noice.nvim` (cmdline + LSP hover/messages; signature disabled — blink.cmp owns it).

### Pickers + Misc — `snacks.nvim`
Single plugin enabling: `picker`, `terminal`, `lazygit`, `dashboard` (preset), `notifier`, `indent` (animated), `bigfile`, `quickfile`, `scope`, `words`, `rename`, `image`, `statuscolumn`, `input`. Provides `<leader><leader>` files, `<leader>fr` recent, `<leader>sg` grep, `<leader>gg` lazygit, plus all LSP go-to pickers (`gd`/`gr`/`gI`/`gy`).

### Treesitter — `treesitter.lua`
Parsers: `bash`, `css`, `eruby`, `html`, `javascript`, `json`, `lua`, `markdown`, `markdown_inline`, `php`, `php_only`, `python`, `regex`, `ruby`, `tsx`, `typescript`, `vim`, `vimdoc`, `yaml`. Plus `nvim-treesitter-context` (3-line sticky header), `nvim-treesitter-textobjects` (`af`/`if`/`ac`/`ic`/`aa`/`ia`), and `nvim-ts-autotag`. Indent uses treesitter except for `ruby`, `eruby` (deferred to built-in indent).

### Productivity — `productivity.lua`
- `typescript-tools.nvim` — TS LSP with custom code actions (`<leader>co` organize, `<leader>cM` add missing imports, `<leader>cU` remove unused, `<leader>cF` fix all)
- `better-ts-errors` — readable TS error expansion (`<leader>dd`)
- `template-string` — auto-converts `"..."` → `` `...` `` on `${`
- `SchemaStore.nvim` — schemas for `jsonls` / `yamlls`
- `symbol-usage.nvim`, `nvim-lightbulb` — code intel hints
- `hardtime.nvim` — habit breaker (max 4 repeats of `hjkl`)
- `satellite.nvim` — decorative scrollbar (`<leader>us`/`uS` toggle)
- `vim-dadbod` + `dadbod-ui` + `dadbod-completion` — DB client (`<leader>D*`)
- `iron.nvim` — REPL (Ruby auto-detects `bin/rails console` → `pry` → `irb`; Python `python3`; Lua `lua`)
- `treewalker.nvim` — AST navigation (`<leader>n*`)

### Workflow — `workflow.lua`
- `overseer.nvim` — task runner (templates auto-discovered from `lua/overseer/template/user/`)
- `persistence.nvim` — per-directory session save/restore
- `claude-code.nvim` — Claude Code terminal toggle (`<leader>ac`)

### Debugging — `dap.lua`
`nvim-dap` + `nvim-dap-view` (modern tabbed panel — `<leader>du` toggle, `<leader>de` watch) + `nvim-dap-virtual-text` + `mason-nvim-dap` (auto-installs `debugpy`, `vscode-php-debug`). The base spec stays language-agnostic; [GAF profile](#gaf-profile) layers PHP xdebug helpers (`<leader>dx/dX/dv/dD`, `:GafXdebug*` user commands) — see [Debugging (PHP / xdebug + DAP)](#debugging-php--xdebug--dap).

### Git — `git.lua`
`gitsigns.nvim` (gutter, blame, hunk ops, `]c`/`[c`), `git-conflict.nvim`, `diffview.nvim` (`<leader>gd`, `<leader>gf` history), `mini.diff` (inline overlay `<leader>go`, `ih` hunk textobj).

### Testing — `test.lua`
`neotest` with adapters: `phpunit` (`vendor/bin/phpunit` by default), `jest`, `vitest`, `python` (pytest, `justMyCode=false`), `rspec`, `minitest`. The [GAF profile](#gaf-profile) swaps phpunit to [`scripts/neotest-run-tests.sh`](scripts/neotest-run-tests.sh) and adds the custom UI test adapter at [`lua/gaf/neotest-ui-tests.lua`](lua/gaf/neotest-ui-tests.lua).

Under GAF profile:
- `<leader>tx` — `bin/run-tests setup` (spins up namespaced Docker silo, writes `.cache/gaf_session_<PID>`).
- `<leader>tX` — `bin/run-tests shutdown` (tears it down).
- `<leader>tp` / `<leader>tP` — run current/last test with `XDEBUG_MODE=profile` for callgrind capture.
- Neotest invocations go through [`scripts/neotest-run-tests.sh`](scripts/neotest-run-tests.sh) which calls `bin/run-tests <relative-path> --filter ... SETUP=false`. Setup must be run explicitly first (or you get "Services are not running").
- Eight Overseer templates in [`lua/overseer/template/user/ui_test_*.lua`](lua/overseer/template/user/) cover `ui:main` × `{watch}` × `{mobile}` × `{devtools}`. Invoke via `<leader>or`. They default `SPECS` to the current buffer's filename, auto-resolve `webapp/` from any cwd, and set `DEVTOOLS=true` for devtools variants.

### Framework-specific
- `ror.lua` — `ror.nvim` (Rails task palette `<leader>r*`), `vim-projectionist` (Rails heuristics — `:A`, `:Emodel`/`Econtroller`/`Eview`/`Espec`), `vim-endwise` (auto-`end` for Ruby/Lua/Vim/Bash), **`tpope/vim-rails`** (`:Rextract`, `:Rinvert`, context-aware `gf` on partials/fixtures/factories, Rails syntax), **Herb LSP** (HTML+ERB, auto-enabled when `herb-language-server` on `$PATH`), **Stimulus LSP** (auto-enabled when `stimulus-language-server` on `$PATH`), **ruby-lsp CodeLens handler** (`rubyLsp.openFile` — route↔action↔view jumps), **`suketa/nvim-dap-ruby`** (rdbg adapter — use existing `<leader>d*` DAP keys), **`andythigpen/nvim-coverage`** (SimpleCov gutter signs via `:Coverage*` commands). Activates on `Gemfile` + `config/environment.rb`.
- `other.lua` — pattern-based related-file navigation (`<leader>oo`/`os`/`ov`) with 50+ Rails patterns, PHP `src/`/`src2/` patterns, and Angular component/datastore patterns.
- `diagram.lua` — Mermaid/PlantUML/D2/Gnuplot inline rendering via Kitty + ImageMagick.

---

## How to Add Things

### Add a new plugin

Create or edit a file under `lua/plugins/` — any `.lua` file there is auto-imported.

```lua
-- lua/plugins/my-plugin.lua
return {
  "author/plugin-name",
  event = "VeryLazy",          -- or `cmd`, `keys`, `ft`
  opts = {
    -- passed to plugin's setup()
  },
  keys = {
    { "<leader>xy", "<cmd>PluginCmd<cr>", desc = "Do thing" },
  },
}
```

Run `:Lazy sync` to install. Commit `lazy-lock.json` after.

### Add an LSP server

1. In [`lua/plugins/lsp.lua`](lua/plugins/lsp.lua), add the server name to `mason-lspconfig`'s `ensure_installed` list.
2. Configure it inside the `nvim-lspconfig` `config` function using `vim.lsp.config(<name>, { settings = {...} })`, then `vim.lsp.enable(<name>)`.
3. If the server needs project-specific settings, gate them on `vim.g.gaf` (see how `basedpyright` extraPaths is gated in `plugins/lsp.lua`, with the actual paths defined in [`lua/gaf/lsp.lua`](lua/gaf/lsp.lua)).

### Add a formatter

Edit `formatters_by_ft` in [`lua/plugins/formatting.lua`](lua/plugins/formatting.lua):

```lua
formatters_by_ft = {
  go = { "gofumpt", "goimports" },   -- runs both, in order
  markdown = { "prettierd", stop_after_first = true },
}
```

Ensure the binary is on `$PATH` (Mason can install many: `:Mason`).

### Add a linter

Edit the `linters_by_ft` block in `formatting.lua`. The default block is empty; add unconditional linters outside the `if vim.g.gaf then ... end` gate. GAF-profile linters live in [`lua/gaf/formatting.lua`](lua/gaf/formatting.lua).

### Add a treesitter parser

Append to the `ensure_installed` list in [`lua/plugins/treesitter.lua`](lua/plugins/treesitter.lua) and run `:TSUpdate`.

If the parser needs custom indent handling, add the filetype to `skip_ts_indent` so treesitter indent doesn't override the built-in.

### Add a treesitter injection

Place a `.scm` file under `queries/<lang>/injections.scm`.

### Add a Snacks picker

Add an entry to the `keys` table in [`lua/plugins/snacks.lua`](lua/plugins/snacks.lua):

```lua
{ "<leader>sX", function() Snacks.picker.git_branches() end, desc = "Git branches" },
```

### Add an Overseer task template

Drop a `.lua` file in [`lua/overseer/template/user/`](lua/overseer/template/user/). It's auto-discovered.

```lua
return {
  name = "yarn dev",
  builder = function()
    return {
      cmd = { "yarn", "dev" },
      components = { "default" },
    }
  end,
  condition = {
    callback = function() return vim.fn.filereadable("package.json") == 1 end,
  },
}
```

Invoke via `<leader>or`.

### Add a global keymap

Edit [`lua/config/keymaps.lua`](lua/config/keymaps.lua) — only put **global, plugin-agnostic** keys here. Plugin-specific keys belong in that plugin's spec under `keys = {...}` so they lazy-load with the plugin.

```lua
vim.keymap.set("n", "<leader>X", function() ... end, { desc = "Do thing" })
```

If your key starts a new group, also add a `which-key` group label in `editor.lua`.

### Add a REPL language

In [`lua/plugins/productivity.lua`](lua/plugins/productivity.lua), extend the `iron.nvim` `repl_definition` table:

```lua
repl_definition = {
  go = { command = { "gore" } },
}
```

### Add a DAP adapter

In [`lua/plugins/dap.lua`](lua/plugins/dap.lua), append to `mason-nvim-dap`'s `ensure_installed`. For non-Mason adapters, configure `dap.adapters` and `dap.configurations` directly.

### Add a related-file mapping (`other.nvim`)

Edit the `mappings` table in [`lua/plugins/other.lua`](lua/plugins/other.lua):

```lua
{
  pattern = "/src/(.*)%.ts$",
  target = { { target = "/test/%1.test.ts", context = "test" } },
},
```

### Add a custom autocmd

Edit [`lua/config/autocmds.lua`](lua/config/autocmds.lua). Always namespace under a group so reloads are clean:

```lua
local group = vim.api.nvim_create_augroup("MyGroup", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = "*.foo",
  callback = function() ... end,
})
```

---

## How to Configure Things

### Change the colorscheme

Edit the `init` block at the top of [`lua/config/lazy.lua`](lua/config/lazy.lua) (`vim.cmd.colorscheme(...)`) and the `config` of the `rose-pine` block in [`lua/plugins/ui.lua`](lua/plugins/ui.lua) — or replace the plugin entirely. The transparent-bg overrides at the bottom of `ui.lua` may need updating to match the new theme's group names.

### Toggle format-on-save

Runtime: `<leader>uf` (toggles globally — see `keymaps.lua`).
Permanent: edit `format_on_save` in [`lua/plugins/formatting.lua`](lua/plugins/formatting.lua).

### Change indent / tab width

[`lua/config/options.lua`](lua/config/options.lua) — `tabstop`, `shiftwidth`, `expandtab`. Filetypes that need different widths should set `indentexpr` or a `FileType` autocmd in `autocmds.lua`.

### Disable a plugin

Add `enabled = false` to its spec block, or comment out the spec. For Snacks features, set `<feature> = { enabled = false }` in the `opts` block in `snacks.lua`.

### Change LSP diagnostic appearance

`vim.diagnostic.config({...})` block in [`lua/plugins/lsp.lua`](lua/plugins/lsp.lua). Note `virtual_text = false` because `tiny-inline-diagnostic` (`ui.lua`) renders diagnostics inline.

### Adjust completion sources / order

`sources.default` array inside the `blink.cmp` spec in `lsp.lua`. Add a new source by also providing it under `sources.providers`.

### Configure database connections

Create `~/.local/share/db_ui/connections.json`:

```json
[
  { "name": "local", "url": "postgres://user:pass@localhost/db" }
]
```

Or set `vim.g.dbs` in your config. Open with `<leader>Du`.

### Pin / update plugins

`:Lazy sync` updates and rewrites `lazy-lock.json`. To pin a plugin, add `version = "v1.2.3"` or `commit = "abc1234"` to its spec. Always commit `lazy-lock.json` after updates.

### Disable hardtime habit breaker

Either `<leader>uh` (if bound), or set `enabled = false` in the `hardtime.nvim` spec in `productivity.lua`. It's already disabled inside `qf`, `oil`, `lazy`, `mason`, `trouble`, `snacks_picker`, `dbui`, `dap`, `aerial`.

---

## Support Files

### `lua/overseer/template/user/`
Custom Overseer task templates, auto-discovered. Currently 9 templates: 8 UI test variants (`ui_test_*.lua`) plus `fli_provision.lua`. Every template's `condition.callback` gates on `vim.g.gaf`, so they only appear in `<leader>or` under the GAF profile. UI test templates share builder logic via [`lua/gaf/ui_test.lua`](lua/gaf/ui_test.lua) — `resolve_webapp_cwd()` walks up from cwd to find the `webapp/` directory.

### `scripts/neotest-run-tests.sh`
PHPUnit wrapper for fl-gaf. Delegates to `bin/run-tests` (so namespacing via `GAF_TEST_WORKER_ID` and session-file lookup are handled upstream). Two transformations:
1. `--filter` value: spaces become `\s` (PCRE-equivalent) — survives `bin/run-tests`' `read -r -a flag_args <<< "$1"` word-split.
2. `--log-junit` path: redirected to `.cache/neotest-junit-$$.xml` (inside Docker bind-mount), then copied to neotest's tempfile after.

Test path is canonicalized via `realpath` and stripped to project-relative (`bin/run-tests` requires `^test/{functional,unit}` etc.). Always runs with `SETUP=false`, so containers must be brought up first via `<leader>tx`. Works in both `fl-gaf/` and `fl-gaf-worktree/<branch>/` since each has its own `bin/run-tests`.

### `docs/keybinds.md`
Hand-maintained 150+ keybinding cheatsheet, grouped by category, with a `Source` column linking each binding back to the file that defines it. Update this when you add or move keymaps.

### `lazy-lock.json`
Plugin lockfile pinning all ~112 plugins. Always commit after `:Lazy sync`.

---

## Project-Specific Behavior

Two persona-level adjustments — one opt-in via env flag, one auto-detected:

- **GAF profile** (env-gated) — see the [GAF Profile](#gaf-profile) section above. All Freelancer-specific behaviors are explicitly opted in via `GAF=1 nvim`. Code lives entirely under `lua/gaf/`, with one-line `if vim.g.gaf then require("gaf.X").Y() end` hooks from base plugin files.
- **Rails** (filetype-gated) — `ror.nvim` + projectionist + vim-rails activate on `Gemfile` + `config/environment.rb`. REPL auto-prefers `bin/rails console` → `pry` → `irb`. ruby_lsp emits CodeLens above controller actions (route → action, action → view); clicking them invokes the `rubyLsp.openFile` handler wired in `ror.lua`. Debug via nvim-dap-ruby — start Rails with `RUBY_DEBUG_OPEN=true bin/rails s`, then attach via `<leader>dc`. Coverage gutter signs via `:CoverageLoad` then `:CoverageShow` (needs SimpleCov + JSON formatter).

To remove GAF tooling entirely, delete `lua/gaf/` and grep for `vim.g.gaf` across `lua/plugins/` to remove the gated blocks.

---

## Snippets

Two sources surface through `blink.cmp`'s `snippets` provider (configured in `lsp.lua` via `search_paths`):

1. **`friendly-snippets`** — community pack (Ruby/Rails/ERB/PHP basics/etc.) under `~/.local/share/nvim/lazy/friendly-snippets/snippets/`.
2. **`~/.config/nvim/snippets/`** — repo-tracked custom snippets, survives plugin updates. Currently ships:
   - `typescript.json` — 41 Angular + RxJS + GAF datastore snippets (`a-*` matches John Papa convention; `fl-ds-*` for company datastore)
   - `php.json` — 40 PHP + GAF Phoenix snippets (bare JetBrains-style: `puf`, `fclass`, `match`; `fl-*` for GAF Controller/Handler/Repository/DTO/Enum/Test/Consumer)
   - `ruby.json` — 93 Rails + Devise + CanCanCan + ActiveAdmin + RSpec + Capybara + HTTP clients + Stimulus + Turbo (bare names: `controller`, `model`, `migration`, `ability`, `aaregister`, `reqspec`, `visit`, `faraday`, `stimcontroller`, `broadcaststo`)
   - `eruby.json` — 29 ERB view helpers + Devise/CanCanCan + Turbo Frames/Streams + Stimulus data attrs (bare: `formwith`, `linkto`, `turboframe`, `datactrl`)

**Trigger naming convention** — researched against industry packs:
- **TypeScript/Angular** — prefix dominates (John Papa `a-*` ~3M installs, BeastCode `ng-*`). Kept `a-*` to match expected muscle memory.
- **PHP/Ruby/ERB** — bare abbreviations dominate (RubyMine, PhpStorm live templates, friendly-snippets, honza/vim-snippets). No `r-` / `p-` namespace in any mainstream pack. Filetype scoping isolates instead.
- **Company-specific** — `fl-*` retained for GAF since company-namespace prefixes are idiomatic when patterns won't generalize beyond the org.

Triggers are word-based — type the prefix, then `<Tab>` or `<CR>` accepts the highlighted match. blink.cmp does **not** auto-show the menu on symbol-only prefixes (`=`, `%`); use a word trigger (`pe`, `er`) for ERB output/exec tags.

To add custom snippets: `<leader>Sa` (scissors writes to `~/.config/nvim/snippets/`). To edit: `<leader>Se`.

### Angular / TypeScript (filetype `typescript`)

Custom prefixes — GAF webapp components default to `standalone: false`, `OnPush`, `inject()` (matches `webapp/` codebase).

| Trigger | Expands to |
|---|---|
| `a-comp` | Non-standalone component, OnPush, `templateUrl` + `styleUrls` |
| `a-comp-sa` | Standalone component with `imports: []` array |
| `a-service` | `@Injectable({providedIn:'root'})` class |
| `a-pipe` | Standalone `@Pipe` w/ `transform()` |
| `a-directive` | Standalone `@Directive` skeleton |
| `a-module` | `@NgModule` w/ `imports`/`declarations`/`exports` |
| `a-guard` / `a-resolver` | Functional `CanActivateFn` / `ResolveFn` |
| `a-input` / `a-output` | `input.required<T>()` / `output<T>()` signal API |
| `a-inject` | `private x = inject(X);` |
| `a-oninit` / `a-ondestroy` | Lifecycle hooks |

RxJS:

| Trigger | Expands to |
|---|---|
| `a-bs` | `BehaviorSubject<T>` private + public `asObservable()` pair |
| `a-subj` / `a-replay` | `Subject<T>` / `ReplaySubject<T>(1)` |
| `a-fvf` | `await firstValueFrom(...)` |
| `a-obs` | `Observable<T>` field declaration |
| `a-combine` | `combineLatest([...]).pipe(map(...))` |
| `a-tud` | `.pipe(takeUntilDestroyed())` |
| `a-pmap` / `a-pfilter` | `.pipe(map(...))` / `.pipe(filter(isDefined))` |
| `a-switch` / `a-merge` | `switchMap` / `mergeMap` |

GAF datastore (matches `webapp/src/@freelancer/datastore/collections/*` patterns):

| Trigger | Expands to |
|---|---|
| `fl-ds-inject` | `private datastore = inject(Datastore);` |
| `fl-ds-coll` | `datastore.collection<XCollection>('x').valueChanges()` |
| `fl-ds-coll-q` | Collection w/ `query.where(field, op, value)` |
| `fl-ds-doc` | `datastore.document<XCollection>('x', id$).valueChanges()` |
| `fl-ds-push` / `fl-ds-set` / `fl-ds-update` / `fl-ds-remove` | Mutation calls |
| `fl-ds-types` | `XCollection` interface (Name/DocumentType/Backend Fetch/Push/Set/Update/Delete/Websocket) |
| `fl-ds-backend` | `Backend<XCollection>` factory w/ `defaultOrder`/`fetch` |
| `fl-ds-reducer` | Reducer w/ `mergeDocuments` + `transformIntoDocuments` |
| `fl-ds-effect` | `@Injectable` effect w/ `createEffect` |
| `fl-ds-module` | `DatastoreXModule` (`StoreModule`/`BackendModule`/`EffectsModule.forFeature`) |
| `fl-ds-transformer` | `transformX(api): X` skeleton |
| `fl-ds-seed` | `generateXObject(overrides)` seed fn |
| `fl-ds-model` | Document interface |
| `fl-ds-index` | Barrel exports (seed/model/module/types) |

### PHP (filetype `php`)

Bare JetBrains-style abbreviations (complement to `friendly-snippets/php/php.json` — collisions resolved by being non-overlapping with defaults):

| Trigger | Expands to |
|---|---|
| `phpns` | `<?php` + `namespace` |
| `fclass` / `aclass` / `iface` | `final class` / `abstract class` / `interface` |
| `puf` / `prf` / `psf` | `public function` / `private function` / `public static function` w/ return type |
| `afn` | Arrow fn `fn(\$x) => ...` |
| `match` | `match` expression |
| `tryl` | try/catch + Logger::error + rethrow |
| `roprop` | `/** @readonly */` private prop |
| `attr` | `#[Attribute]` |
| `sqlhd` | `<<<'SQL' ... SQL;` heredoc |
| `logerr` / `loginfo` / `logwarn` | Logger calls |
| `docthrows` / `docapi` / `doccovers` | PHPDoc blocks |

GAF Phoenix patterns (matches `src2/` conventions — `final class`, namespace `Freelancer\Phoenix\...`, MyCLabs enums, `MySql::` service, `?Dep \$d = null` constructor injection):

| Trigger | Expands to |
|---|---|
| `fl-controller` | Phoenix Controller w/ `MethodNotAllowedException` guard, promoted handler injection |
| `fl-handler` | Phoenix Handler w/ optional injected dep + `??` fallback, `@readonly` prop |
| `fl-repo` | Phoenix Repository (uses `MySql` + DTO + Logger) |
| `fl-dto` | `final class XxxDTO` w/ `@psalm-immutable`, promoted public props |
| `fl-enum` | MyCLabs string Enum w/ `EnumPrettyPrintTrait`, `@method static self X()` docs |
| `fl-enum-native` | PHP 8.1 native backed enum |
| `fl-mysql-one` / `fl-mysql-all` | `MySql::fetchOne` / `MySql::fetchAll` w/ named args |
| `fl-mysql-insert` / `fl-mysql-exec` | `MySql::insert` / `MySql::executeStatement` |
| `fl-repo-fetch` | Full repo fetch fn: heredoc SQL + try/catch DBQueryException/Exception + Logger |
| `fl-test-fn` | `FunctionalTestCase` + `IsolateAndRollbackTestCase` skeleton |
| `fl-test-unit` | `PHPUnit\Framework\TestCase` skeleton |
| `fl-test-method` | `public function testX(): void` |
| `fl-test-provider` | `@dataProvider iterable<string, array{...}>` provider |
| `fl-assert` | `self::assertSame(expected, actual)` |
| `fl-consumer` | Legacy RabbitMQ consumer script (callback w/ basic_ack/reject + DBConnect/Rabbit/Exception handling) |
| `fl-inject` | Constructor optional dep + `\$this->x = \$x ?? new X()` |
| `fl-bad-req` / `fl-not-found` / `fl-mna` | Throw `BadRequestException` / `NotFoundException` / `MethodNotAllowedException` guard |

---

## Ruby / Rails / ERB Snippets

Default Ruby/RSpec/ERB and basic Rails (associations, validations, simple migrations) ship via `friendly-snippets`. Custom additions cover modern Rails 7+ patterns and common gems.

### Plain Ruby (filetype `ruby`, friendly-snippets defaults)

| Trigger | Expands to |
|---|---|
| `cla` | `class Name ... end` |
| `mod` | `module Name ... end` |
| `def` | `def name(args) ... end` |
| `defs` | `def self.name ... end` |
| `ata` / `atr` / `atw` | `attr_accessor` / `attr_reader` / `attr_writer` |
| `each` | `coll.each do \|item\| ... end` |
| `map` / `sel` / `inj` | `map` / `select` / `inject` block |
| `if` / `ife` | `if ... end` / `if/else/end` |
| `unless` / `unlesse` | `unless ... end` / `unless/else/end` |
| `beg` | `begin / rescue => e / end` |
| `req` / `reqr` | `require '...'` / `require_relative '...'` |
| `do` | `do \|args\| ... end` |

### Rails models

| Trigger | Expands to |
|---|---|
| `val` / `vali` | `validates :attr, presence: true` |
| `vap` | `validates_presence_of :attr` |
| `hm` / `hmt` / `ho` / `bt` / `habtm` | association macros |
| `sco` | `scope :name, -> { where(...) }` |
| `bfs` / `bfv` / `afs` | `before_save` / `before_validation` / `after_save` |
| `enum` | `enum status: { active: 0, archived: 1 }` |

### Rails controllers

| Trigger | Expands to |
|---|---|
| `cont` | controller class skeleton |
| `defi` / `defsh` / `defc` / `defu` / `defd` | `index` / `show` / `create` / `update` / `destroy` actions |
| `pp` / `params` | `params.require(:m).permit(:a, :b)` |
| `ba` | `before_action :method, only: [...]` |
| `respond` | `respond_to do \|format\| ... end` |

### Migrations

| Trigger | Expands to |
|---|---|
| `mcc` | `create_table :name do \|t\| ... t.timestamps end` |
| `mac` | `add_column :table, :col, :type` |
| `mcc2` | `change_column :table, :col, :type` |
| `mrc` | `remove_column :table, :col` |
| `mai` | `add_index :table, :col` |
| `mrf` | `t.references :model, foreign_key: true` |
| `tst` / `tint` / `tbool` / `tdt` / `ttxt` | `t.string` / `t.integer` / `t.boolean` / `t.datetime` / `t.text` |

### RSpec (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `desc` | `describe ClassName do ... end` |
| `cont` | `context "when ..." do ... end` |
| `it` | `it "does X" do ... end` |
| `bef` | `before(:each) do ... end` |
| `let` / `let!` | `let(:n) { v }` / eager `let!` |
| `exp` | `expect(actual).to eq(expected)` |
| `sub` | `subject { described_class.new(...) }` |

### ERB (filetype `eruby`)

| Trigger | Expands to |
|---|---|
| `pe` (or `=`) | `<%= %>` output tag |
| `er` (or `%`) | `<% %>` silent tag |
| `pc` | `<%# %>` comment tag |
| `if` / `ife` / `elsif` / `else` / `end` | flow control wrapped in ERB |
| `unless` / `unlesse` | unless block |
| `each` | `<% items.each do \|i\| %> ... <% end %>` |
| `lt` | `<%= link_to text, path %>` |

> Symbol prefixes `=` / `%` exist in `friendly-snippets/erb.json` but blink.cmp's keyword regex won't auto-trigger the menu on them. Type `pe` / `er` instead for reliable expansion. To force the menu, press `<C-Space>`.

### FactoryBot

| Trigger | Expands to |
|---|---|
| `fact` | `factory :model do ... end` |
| `trait` | `trait :name do ... end` |
| `seq` | `sequence(:attr) { \|n\| "v#{n}" }` |
| `assoc` | `association :model` |

Source files: `~/.local/share/nvim/lazy/friendly-snippets/snippets/ruby/{ruby,rspec,rdoc}.json` and `.../snippets/erb.json`.

### Custom Rails additions (filetype `ruby`)

Bare descriptive triggers (matching honza/vim-snippets + RubyMine convention — no `r-` prefix). Filetype scoping isolates them.

| Trigger | Expands to |
|---|---|
| `controller` | Full RESTful controller (index/show/new/create/edit/update/destroy + set + strong params) |
| `apicontroller` | API-only controller w/ JSON responses |
| `renderjson` / `rendererr` | `render json:` w/ status / error JSON |
| `redir` / `headresp` | `redirect_to` w/ flash / `head :no_content` |
| `strongparams` | strong params method |
| `baction` / `baexcept` | `before_action only:` / `except:` |
| `rescuefrom` | `rescue_from` block |
| `model` | Model w/ associations + validations + scope + callback |
| `concern` | `ActiveSupport::Concern` module skeleton |
| `delegate` / `hsp` / `aftercommit` | `delegate to:` / `has_secure_password` / `after_commit` |
| `valength` / `vauniq` / `vaformat` / `vainclusion` / `vanum` | length / uniqueness / format / inclusion / numericality validations |
| `migration` | `create_table` migration w/ references + index + timestamps |
| `migud` | `up` / `down` reversible migration |
| `addref` / `addfk` / `adduniq` / `ccnull` / `reversible` | add_reference / add_foreign_key / unique index / change_column_null / reversible block |
| `resources` / `nestedres` / `namespace` / `rscope` / `rroot` / `constraints` | resources w/ member+collection / nested / namespace / scope module / root / constraints |
| `job` | `ApplicationJob` w/ `queue_as` + `retry_on` |
| `mailer` | `ApplicationMailer` w/ default + `mail` call |
| `service` | PORO service w/ `.call` class method |
| `channel` | `ApplicationCable::Channel` |

### Devise (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `authuser` | `before_action :authenticate_user!` |
| `signedin` | `if user_signed_in?` guard |
| `devisepermit` | `configure_permitted_parameters` w/ devise_parameter_sanitizer |
| `devisemodel` | Devise User model (modules) |
| `devisefor` | `devise_for :users` route |

### CanCanCan (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `ability` | `Ability` class w/ `include CanCan::Ability` and admin/user split |
| `loadauth` | `load_and_authorize_resource` |
| `authres` / `authbang` | `authorize_resource` / `authorize! :action, resource` |
| `canq` | `can? :action, resource` |
| `rescueaccess` | `rescue_from CanCan::AccessDenied` |

### ActiveAdmin (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `aaregister` | `ActiveAdmin.register` w/ permit_params + index + form + show |
| `aafilter` / `aascope` | `filter` / `scope` |
| `aaaction` | `action_item only: :show` |
| `aabatch` / `aamember` | `batch_action` / `member_action` |
| `aasidebar` | `sidebar` block |

### RSpec extras (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `reqspec` | Request spec (`type: :request`) |
| `modelspec` | Model spec w/ shoulda matchers |
| `sysspec` | System spec w/ `driven_by` |
| `sharedex` / `behaveslike` | `shared_examples` / `it_behaves_like` |
| `ctxlet` | `context` w/ `let` + `it` |
| `fbcreate` / `fbbuild` / `fblist` | FactoryBot `create` / `build` / `create_list` |
| `stubi` / `stubc` | Stub instance / `allow_any_instance_of` |
| `expchange` / `expraise` | `expect { }.to change` / `to raise_error` |
| `expstatus` / `jsonbody` | `have_http_status` / `JSON.parse(response.body)` |

### Capybara (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `visit` | `visit path` |
| `fillin` / `clickbtn` / `clicklink` | `fill_in` / `click_button` / `click_link` |
| `selectopt` / `checkbox` / `attachfile` | `select`/`check`/`attach_file` |
| `havecontent` / `havecss` / `havepath` | `have_content` / `have_css` / `have_current_path` |
| `within` | `within '.selector' do ... end` |

### HTTP clients (filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `nethttpget` | `Net::HTTP.get_response` w/ JSON parse |
| `nethttppost` | `Net::HTTP::Post` w/ JSON body + SSL |
| `faraday` | Faraday connection w/ json req/resp middleware |
| `httparty` | HTTParty client class skeleton |
| `restclient` | RestClient call |

### Stimulus (filetype `ruby` — JS files inside Rails projects)

> Snippets currently registered under `ruby` filetype since Rails devs edit in the Rails project. To use in `.js` files, set filetype manually or copy to `typescript.json`.

| Trigger | Expands to |
|---|---|
| `stimcontroller` | Full Stimulus controller (targets/values/classes/connect/disconnect/action) |
| `stimaction` | Action method w/ `event.preventDefault()` |
| `stimtarget` | `this.nameTarget` accessor |

### Custom ERB additions (filetype `eruby`)

Rails view helpers, Devise/CanCanCan view guards, Turbo Frames + Streams, Stimulus data attributes.

| Trigger | Expands to |
|---|---|
| `formwith` | `form_with model:` w/ field + submit |
| `formwithurl` | `form_with url:` |
| `ffield` / `fsubmit` | form field row / submit button |
| `renderpartial` / `rendercollection` | partial / collection render |
| `linkto` / `linkdelete` | `link_to` / delete w/ `turbo_method`+`turbo_confirm` |
| `buttonto` | `button_to` w/ method |
| `imagetag` / `assetpath` | `image_tag` / `asset_path` |
| `contentfor` / `yieldblock` | `content_for` block / `yield :title` |
| `flasheach` | flash each loop |
| `csrfmeta` | `csrf_meta_tags` + `csp_meta_tag` |
| `deviselinks` | Devise sign in/out links |
| `canqif` | ERB `<% if can? %>` guard |
| `turboframe` / `turboframelazy` | `turbo_frame_tag` / lazy variant |
| `turbostreamfrom` | `turbo_stream_from` |
| `turboreplace` / `turboappend` / `turboremove` | turbo_stream actions |
| `datactrl` / `dataaction` / `datatarget` / `datavalue` | Stimulus data-* attributes |
| `stimwrap` | div wrapper w/ controller + target + action |
| `aainput` | ActiveAdmin `f.input` line |

### Turbo (model-side, filetype `ruby`)

| Trigger | Expands to |
|---|---|
| `broadcaststo` | `broadcasts_to` w/ array stream key |
| `broadcastsrefresh` | `broadcasts_refreshes` |
| `respondturbo` | controller `respond_to` w/ turbo_stream + html |
| `renderturbo` | `render turbo_stream: turbo_stream.replace(...)` |

---

## Multicursor

Plugin: [`jake-stewart/multicursor.nvim`](https://github.com/jake-stewart/multicursor.nvim) (branch `1.0`), configured in [`lua/plugins/editor.lua`](lua/plugins/editor.lua). VSCode-style multi-cursor editing for Neovim — `Cmd+D` style match-add, column edit, mouse picks, regex split, transpose, align.

### Bindings

**Match-based (VSCode `Cmd+D`)** — operate on word under cursor or visual selection:

| Key | Mode | Action |
|---|---|---|
| `<leader>mn` | n, x | Add cursor at next match |
| `<leader>mN` | n, x | Add cursor at prev match |
| `<leader>ms` | n, x | Skip current match (forward) |
| `<leader>mS` | n, x | Skip current match (backward) |
| `<leader>ma` | n, x | Add cursor at every match in buffer |

**Column edit (line-based)** — sticky column, walks vertically:

| Key | Mode | Action |
|---|---|---|
| `<leader>mj` | n, x | Add cursor on line below |
| `<leader>mk` | n, x | Add cursor on line above |
| `<leader>mJ` | n, x | Skip line down (move main cursor) |
| `<leader>mK` | n, x | Skip line up |

**Utilities:**

| Key | Mode | Action |
|---|---|---|
| `<leader>mx` | n, x | Delete cursor under main |
| `<leader>mr` | n | Restore cursors (after accidental clear) |
| `<leader>ml` | n, x | Align cursors to same column (insert spaces) |
| `<leader>mp` | x | Split visual selection by regex → cursor per match |
| `<leader>mt` | x | Transpose text between cursors (rotate) |
| `<C-q>` | n, x | Toggle cursor at current position |
| `<C-LeftMouse>` | n | Toggle cursor at clicked location |

**Cursor layer** (active **only** while extra cursors exist — does not affect normal-mode keys otherwise):

| Key | Action |
|---|---|
| `<Tab>` / `<Right>` | Cycle main cursor → next |
| `<S-Tab>` / `<Left>` | Cycle main cursor → prev |
| `<Esc>` | Clear all cursors (or re-enable if disabled) |

### Workflows

**1. Rename variable across visible scope (VSCode `Cmd+D`)**
```
foo = 1; foo + foo  →  bar = 1; bar + bar
```
- Cursor on `foo`
- `<leader>mn` `<leader>mn` — add cursor at each next `foo`
- `cw bar <Esc>` — replace all
- `<Esc>` — clear cursors

**2. Add trailing comma to a list (column edit)**
```
apple
banana
cherry
```
- End of `apple` (`$`)
- `<leader>mj` `<leader>mj` — three cursors stacked at line end
- `a, <Esc>` — comma appended to each
- `<Esc>`

**3. Wrap every occurrence of a token in quotes**
- Visual-select `id`
- `<leader>ma` — cursor at every `id`
- `c"<C-r>""<Esc>` — wraps each

**4. Split CSV into per-item cursors**
```
a,b,c,d
```
- Visual-select the whole CSV
- `<leader>mp` — prompts for regex; enter `,`
- One cursor per item — edit independently

**5. Align assignment operators**
```
x = 1
yy = 2
zzz = 3
```
- Cursor on first `=`, `<leader>mj` chain to add cursor on each `=`
- `<leader>ml` — pads with spaces so all `=` line up

**6. Transpose values between cursors**
- Place cursors on `A`, `B`, `C` in visual mode
- `<leader>mt` — content rotates: `A→B→C→A`

**7. Pick scattered locations with mouse**
- `<C-LeftMouse>` at line 5, line 23, line 47
- Edit all three simultaneously

**8. Recover from fat-fingered Esc**
- Accidental `<Esc>` cleared cursors? — `<leader>mr` brings them back

**9. Match in selection only**
- Visual-select a function body
- `<leader>ma` — adds cursor at every match **inside** the selection (not whole buffer)

### Notes / gotchas

- **`<C-q>`** previously meant quickfix toggle in some setups. Here it's claimed by multicursor (no other plugin in this config uses it).
- **`<Esc>`** in normal mode globally is `:noh` ([`keymaps.lua:29`](lua/config/keymaps.lua)). The cursor-layer `<Esc>` only overrides while cursors exist; `:noh` works as before otherwise.
- **`<Tab>`/`<S-Tab>`** are not globally remapped, and blink.cmp's Tab handling is insert-mode only — no conflict in cursor layer.
- **Treesitter incremental selection** uses `<CR>`/`<BS>`, not Tab — also no conflict.
- which-key labels the `<leader>m` group as `multicursor` ([`editor.lua:320`](lua/plugins/editor.lua)).
- The plugin is lazy-loaded via the `keys =` table, so no startup cost until first use.

---

## Debugging (PHP / xdebug + DAP)

End-to-end debug workflow for the GAF PHP monorepo. Requires the [GAF profile](#gaf-profile) (`GAF=1 nvim`). The `vscode-php-debug` adapter is installed automatically by `mason-nvim-dap` and listens on port `9003` (xdebug 3 default).

### Setup (one-time)

1. **Launch with GAF profile** — `GAF=1 nvim` (or `gnvim` alias). Without it, `:GafXdebug*` commands are not registered.
2. **Install xdebug** locally (`pecl install xdebug`) — only required if you run PHP directly on the host. Container/devbox flows already ship it.
3. **Configure your devbox name** — set in [`lua/gaf/paths.lua`](lua/gaf/paths.lua) (`M.dev_dns`). Defaults to `rtanjaya`.
4. **Validate** — open a PHP file in `fl-gaf`, then `<leader>dv` (runs `bin/gaf-xdebug validate`). Fix anything it reports.

### Keymaps

| Key | Action |
|---|---|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Continue / start listener (picks `Listen for Xdebug (:9003)`) |
| `<leader>di` / `do` / `dO` | Step into / over / out |
| `<leader>dt` | Terminate session |
| `<leader>dl` | Run last config |
| `<leader>du` | Toggle dap-view UI |
| `<leader>de` | Watch expression (normal + visual) |
| `<leader>dx` | `:GafXdebugStart` — start port-forward (`bin/gaf-xdebug start`) |
| `<leader>dX` | `:GafXdebugStop` — stop port-forward |
| `<leader>dv` | `:GafXdebugValidate` — IDE validation |
| `<leader>dD` | Toggle `GAF_DEBUG=1` env (neotest then passes `--debug`) |

User commands (defined in [`lua/gaf/xdebug.lua`](lua/gaf/xdebug.lua)):
`:GafXdebugStart`, `:GafXdebugStop`, `:GafXdebugValidate`, `:GafXdebugLogs`, `:GafXdebugInsert` (inserts `xdebug_connect_to_client();` at cursor).

### DAP configuration

Registered once on first `FileType=php` event from [`lua/gaf/dap.lua`](lua/gaf/dap.lua) (hooked by `lua/plugins/dap.lua` when GAF profile is active):

```lua
dap.configurations.php = {
  {
    type = "php",
    request = "launch",
    name = "Listen for Xdebug (:9003)",
    port = 9003,
    pathMappings = { ["/mnt/gaf"] = "~/freelancer-dev/fl-gaf" },
  },
}
```

One config covers every workflow — `pathMappings` is harmless when paths already match (local runs) and required for remote (devbox `/mnt/gaf` → local checkout).

### Workflows

**1. HTTP request (remote devbox)**
```
<leader>dx          → port-forward up
<leader>db          → breakpoint in handler
<leader>dc          → start listener on :9003
curl https://rtanjaya.syd1.fln-dev.net/... -H 'cookie: XDEBUG_SESSION=1'
                    → breakpoint hits, dap-view opens
<leader>dt          → done
<leader>dX          → stop port-forward
```

Browser alternative: install [Xdebug Helper](https://github.com/JetBrains/xdebug-extension) extension, set to **Debug** mode, reload the page.

**2. Thrift / Consumer / CLI script (remote)**

Code must explicitly connect — xdebug doesn't auto-attach for non-HTTP entry points.

```
xdc<Tab>            → snippet inserts xdebug_connect_to_client();
                      (or :GafXdebugInsert at cursor)
fli service sync fl-gaf --skip-php-dependencies --skip-thrift
<leader>dx          → port-forward up
<leader>dc          → start listener
# Trigger the consumer / Thrift call / re-run the script
```

For scripts run on the remote host, also `export PHP_IDE_CONFIG="serverName=rtanjaya"` before `sudo -E -u www-data php ...`.

**3. Functional test (local Docker)**

```
<leader>tx          → bin/run-tests setup  (once per session)
<leader>db          → breakpoint in test OR code under test
<leader>dD          → toggle GAF_DEBUG=1
<leader>dc          → start listener on :9003
<leader>tr          → run nearest test (wrapper auto-appends --debug)
                      breakpoint hits, dap-view opens
<leader>dD          → toggle GAF_DEBUG off when done (xdebug slows tests ~5x)
```

The wrapper [`scripts/neotest-run-tests.sh`](scripts/neotest-run-tests.sh) mirrors the coverage-flag pattern: `GAF_DEBUG=1` in the env → `--debug` appended to `bin/run-tests`.

**4. Unit test (local)**

```
<leader>db          → breakpoint
<leader>dc          → listener
XDEBUG_MODE=debug bin/gaf-php vendor/bin/phpunit test/unit/src/...
```

Or via neotest with `<leader>dD` toggled — same flow as functional tests.

**5. PHP script (local, dockerised)**

```
<leader>db          → breakpoint
<leader>dc          → listener
XDEBUG_MODE=debug bin/gaf-php scripts/playground.php
```

### Path mapping

The hardcoded mapping is `/mnt/gaf` → `~/freelancer-dev/fl-gaf`. Constants live in [`lua/gaf/paths.lua`](lua/gaf/paths.lua) (`remote_root` / `fl_gaf`). Edit there to relocate the checkout.

### Snippets

| Trigger | Filetype | Expands to |
|---|---|---|
| `xdc` | `php` | `xdebug_connect_to_client();` (for Thrift/consumer/script) |

### Troubleshooting (debug-specific)

- **Breakpoint shows as "rejected"** — path mapping is wrong. `<leader>du` → breakpoints tab, check `verified` status. Confirm `/mnt/gaf` is the container mount target (always is for fl-gaf devboxes).
- **Listener never connects** — check `xdebug.client_host`. In containers it should resolve to the host: `host.docker.internal` (macOS) or the host gateway IP (Linux). `bin/gaf-xdebug logs` (`:GafXdebugLogs`) shows xdebug's side.
- **`:echo $GAF_DEBUG` is empty after toggle** — neotest spawns the wrapper as a child process; it inherits `vim.env`. If you toggled in a different nvim instance, the flag doesn't propagate.
- **Tests run but no breakpoint hits** — listener may have disconnected. nvim-dap stops listening on each session end; press `<leader>dc` again (or `<leader>dl` for last config) before the next test run.
- **Listener won't bind to `:9003`** — another instance still running. `:lua print(vim.inspect(require("dap").session()))` and `<leader>dt` to terminate. PHP-FPM uses `:9000` so won't collide with `:9003`.
- **`bin/gaf-xdebug` not found** — `:GafXdebug*` commands walk up from the current buffer (then cwd) looking for `bin/gaf-xdebug`. Open any file inside `fl-gaf` (or `cd` into it) first.

### Other languages

- **Ruby (rdbg)** — `nvim-dap-ruby` adapter loads on `FileType=ruby` (see [`lua/plugins/ror.lua`](lua/plugins/ror.lua)). Start Rails with `RUBY_DEBUG_OPEN=true bin/rails s`, then `<leader>dc` attaches.
- **Python (debugpy)** — auto-installed via mason. `<leader>dc` picks "Launch file" or attach. Neotest debugs via `<leader>td` (uses `strategy = "dap"`, `justMyCode=false`).

---

## Troubleshooting

**Plugins didn't install** — Run `:Lazy` to inspect status; `:Lazy sync` to retry.

**LSP not attaching** — `:LspInfo` shows status. `:Mason` to check installs. `:checkhealth lsp`. Confirm the server is in `ensure_installed` in `lsp.lua`.

**Treesitter parser missing** — `:TSInstall <lang>` or `:TSUpdate`.

**Format-on-save broken** — `<leader>uf` to toggle, `:ConformInfo` to see formatter status, check binaries are on `$PATH`.

**Slow startup** — `:Lazy profile` shows per-plugin load time. Most plugins here use `event = "VeryLazy"` or lazy-load on `keys` / `cmd` / `ft`.

**Hover floats shrink on long signatures** — Known Neovim 0.12.x bug; `autocmds.lua` has a wrapper patching `vim.lsp.util.open_floating_preview`. Remove the patch when upstream fix lands.

**Diagnostics look duplicated** — `tiny-inline-diagnostic` renders inline; `lsp.lua` sets `virtual_text = false` to compensate. If you re-enable virtual text, you'll get both.

**`:checkhealth`** is your friend — run it after first install.
