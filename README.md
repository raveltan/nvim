# Neovim Configuration

A modular, LSP-first Neovim configuration built on [lazy.nvim](https://github.com/folke/lazy.nvim). Optimized for polyglot development across TypeScript/Angular, PHP/Laravel, Ruby on Rails, and Python, with first-class support for the Freelancer.com monorepo (`fl-gaf`) and Phabricator workflows.

> Looking for the keybind cheatsheet? See [`docs/keybinds.md`](docs/keybinds.md).

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Layout](#layout)
- [Bootstrap Flow](#bootstrap-flow)
- [Core Options](#core-options)
- [Keymap Conventions](#keymap-conventions)
- [Plugins by Category](#plugins-by-category)
- [How to Add Things](#how-to-add-things)
- [How to Configure Things](#how-to-configure-things)
- [Support Files](#support-files)
- [Project-Specific Behavior](#project-specific-behavior)
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
- `stylua`, `prettierd` / `prettier`, `php-cs-fixer` / `pint`, `blade-formatter` (formatters)
- `phpcs`, `phpstan` (linters — Freelancer projects only)
- `rubocop` (gem), `erb-formatter` gem (provides `erb_format`), `@herb-tools/language-server` (npm) for Rails ERB
- `mmdc`, `d2`, `plantuml`, `gnuplot`, `imagemagick` (diagram rendering, optional)

---

## Installation

```sh
git clone <this-repo> ~/.config/nvim
nvim
```

On first launch, lazy.nvim bootstraps itself, installs all plugins from `lua/plugins/*.lua`, and triggers Mason to fetch language servers. Restart once installs complete.

Lockfile: [`lazy-lock.json`](lazy-lock.json) pins **106 plugins**. Use `:Lazy sync` to update; commit the lockfile after.

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
│   │   ├── neotest-ui-tests.lua  # Custom Neotest adapter for fl-gaf UI tests
│   │   └── ui_test.lua           # Helper for fl-gaf UI test overseer templates
│   ├── plugins/                  # One file per category — lazy auto-imports all
│   │   ├── editor.lua            # Editing UX (flash, surround, multicursor, ...)
│   │   ├── formatting.lua        # conform.nvim + nvim-lint
│   │   ├── lsp.lua               # Mason, lspconfig, blink.cmp, trouble
│   │   ├── nav.lua               # oil, harpoon, jumppack, glance, tmux-navigator
│   │   ├── ui.lua                # rose-pine, lualine, noice, zen-mode
│   │   ├── snacks.lua            # snacks.nvim (picker, dashboard, terminal, ...)
│   │   ├── treesitter.lua        # parsers, textobjects, context, autotag
│   │   ├── productivity.lua      # typescript-tools, dadbod, iron, satellite
│   │   ├── workflow.lua          # overseer, persistence, git-worktree, claude-code
│   │   ├── dap.lua               # Debugger
│   │   ├── git.lua               # gitsigns, diffview, git-conflict
│   │   ├── test.lua              # neotest + adapters
│   │   ├── laravel.lua           # Laravel-specific
│   │   ├── ror.lua               # Rails-specific
│   │   ├── other.lua             # other.nvim — related-file navigation
│   │   └── diagram.lua           # mermaid/d2/plantuml inline render
│   └── overseer/template/user/   # Custom overseer task templates (auto-discovered)
├── queries/php/injections.scm    # Treesitter: inject Blade into Livewire PHP files
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
| `<leader>c` | **C**ode / LSP | `ca` action, `cr` rename, `cf` format, `co` organize imports (TS) |
| `<leader>d` | **D**ebug (DAP) | `db` breakpoint, `dc` continue, `du` UI, `de` eval |
| `<leader>D` | **D**adbod (DB) | `Du` UI, `Df` find buffer, `Dq` last query |
| `<leader>e` | **E**xplorer | `e` open oil |
| `<leader>f` | **F**ind | `fr` recent, `fc` config, `fn` new file, `fR` rename |
| `<leader>g` | **G**it | `gg` lazygit, `gd` diffview, `gb` blame, `gh*` hunk ops, `gw*` worktree |
| `<leader>h` | **H**arpoon | `ha` add, `hh` toggle |
| `<leader>H` | **H**url (REST) | `Ha` run all, `Hs` at cursor |
| `<leader>i` | **I**ron (REPL) | `is` toggle, `ic` send motion, `iv` send visual |
| `<leader>l` | **L**aravel | `ll` picker, `la` artisan, `lr` routes |
| `<leader>m` | **M**ulticursor | `mn` next, `ma` all matches |
| `<leader>n` | Tree**w**alker | `nk/nj/nh/nl` AST up/down/parent/child |
| `<leader>o` | **O**verseer | `or` run, `oc` shell command, `ot` toggle list |
| `<leader>q` | **Q**uit / Session | `qq` quit all, `qs` restore session |
| `<leader>r` | **R**ails | `rc` commands, `rg` generate, `rs` schema, `rC` console |
| `<leader>R` | **R**efactor | `Re` extract function, `Rv` extract var |
| `<leader>s` | **S**earch | `sg` grep, `sw` grep word, `ss` symbols, `sr` find/replace |
| `<leader>S` | **S**nippets | `Se` edit, `Sa` add |
| `<leader>t` | Checkma**t**e | Markdown todo metadata |
| `<leader>T` | **T**ests (Neotest) | `Tr` run nearest, `Tf` file, `Td` debug, `Ts` summary |
| `<leader>u` | **U**I toggles | `uz` zen, `ud` diagnostics, `uf` format-on-save, `uM` markdown render |
| `<leader>x` | Diagnostics / lists | `xx` trouble, `xq` quickfix, `xl` loclist |
| `<leader>a` | Cl**a**ude Code | `ac` toggle, `aC` continue, `ar` resume |

Other notable global keymaps (from `config/keymaps.lua`):

- `<C-h/j/k/l>` — split + tmux pane navigation
- `<S-h>` / `<S-l>` — previous / next buffer
- `<A-j>` / `<A-k>` — move line(s) down / up (works in visual)
- `<C-s>` — save (n/i/v/s)
- `gw` — grep word under cursor (Snacks)
- `gx` — open URL under cursor; **detects Phabricator `D####` / `T####` tokens** and rewrites to `https://phabricator.tools.flnltd.com/...`
- `n` / `N` — search next/prev with hlslens count + recenter
- `<C-d>` / `<C-u>` — half-page scroll, cursor recentered
- `<Esc><Esc>` — exit terminal mode

Full reference: [`docs/keybinds.md`](docs/keybinds.md).

---

## Plugins by Category

### Editing UX — `editor.lua`
`vim-sleuth`, `nvim-ufo`, `undotree`, `treesj`, `refactoring.nvim`, `ultimate-autopair`, `mini.surround` (`gs` prefix), `grug-far` (search/replace), `flash.nvim` (`s`/`S` jumps), `markview.nvim`, `todo-comments`, `mini.bufremove`, `mini.ai`, `yanky` (100-entry yank ring), `multicursor.nvim`, `hurl.nvim`, `nvim-bqf`, `nvim-hlslens`, `dial.nvim`, `ts-comments`, `vim-matchup`, `nvim-scissors`, `marks.nvim`, `which-key`, `checkmate.nvim`, `vim-repeat`, `vim-abolish`, `vim-illuminate`.

### LSP & Completion — `lsp.lua`
- **Mason** + **mason-lspconfig** auto-install: `eslint`, `basedpyright`, `ruff`, `intelephense`, `jsonls`, `yamlls`, `tailwindcss`, `html`, `cssls`
- **TypeScript** is handled by `typescript-tools.nvim` in `productivity.lua` (faster than `ts_ls`)
- **blink.cmp** — completion (sources: `lsp` → `path` → `snippets` → `buffer`, max 50 LSP items, prefer-rust fuzzy)
- **fidget.nvim** — LSP progress
- **trouble.nvim** — diagnostics panel (`<leader>xx`)
- **inc-rename**, **actions-preview.nvim** — improved rename + code action UI
- **lazydev.nvim** — Lua LSP awareness for `vim.*` API
- Diagnostics: `virtual_text` off (handled by `tiny-inline-diagnostic`); custom signs `✘ ⚠ ℹ ⚡`

### Formatting & Linting — `formatting.lua`
- `conform.nvim`: `stylua` (Lua), `prettierd`/`prettier` (JS/TS), `php-cs-fixer`/`pint` (PHP), `blade-formatter` (Blade), `ruff_organize_imports` + `ruff_format` (Python)
- `nvim-lint`: PHP `phpcs` + `phpstan` — **only enabled inside Freelancer projects**, with project-specific configs (`phpcs_gaf.xml`, `phpstan.neon`)
- Format-on-save: enabled (3s timeout, LSP fallback). Toggle with `<leader>uf`.

### Navigation — `nav.lua`
`vim-tmux-navigator`, `oil.nvim` (file explorer with hidden files), `harpoon2` (`<leader>1-4` jump), `Jumppack.nvim`, `glance.nvim` (`gD`/`gR`/`gY`/`gM` peek).

### UI — `ui.lua`
`rose-pine` (main variant, transparent backgrounds), `mini.icons`, `lualine.nvim`, `rainbow-delimiters`, `nvim-colorizer.lua`, `tiny-inline-diagnostic` (powerline preset), `zen-mode.nvim` (120 cols), `noice.nvim` (cmdline + LSP hover/messages; signature disabled — blink.cmp owns it).

### Pickers + Misc — `snacks.nvim`
Single plugin enabling: `picker`, `terminal`, `lazygit`, `dashboard` (preset), `notifier`, `indent` (animated), `bigfile`, `quickfile`, `scope`, `words`, `rename`, `image`, `statuscolumn`, `input`. Provides `<leader><leader>` files, `<leader>fr` recent, `<leader>sg` grep, `<leader>gg` lazygit, plus all LSP go-to pickers (`gd`/`gr`/`gI`/`gy`).

### Treesitter — `treesitter.lua`
Parsers: `bash`, `blade`, `css`, `eruby`, `html`, `javascript`, `json`, `lua`, `markdown`, `markdown_inline`, `php`, `php_only`, `python`, `regex`, `ruby`, `tsx`, `typescript`, `vim`, `vimdoc`, `yaml`. Plus `nvim-treesitter-context` (3-line sticky header), `nvim-treesitter-textobjects` (`af`/`if`/`ac`/`ic`/`aa`/`ia`), and `nvim-ts-autotag`. Indent uses treesitter except for `blade`, `ruby`, `eruby` (deferred to built-in indent).

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
- `git-worktree.nvim` — worktree switcher with chdir hook
- `claude-code.nvim` — Claude Code terminal toggle (`<leader>ac`)

### Debugging — `dap.lua`
`nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text` + `mason-nvim-dap` (auto-installs `debugpy`, `vscode-php-debug`).

### Git — `git.lua`
`gitsigns.nvim` (gutter, blame, hunk ops, `]c`/`[c`), `git-conflict.nvim`, `diffview.nvim` (`<leader>gd`, `<leader>gf` history, `<leader>gF` branch history).

### Testing — `test.lua`
`neotest` with adapters: `phpunit` (auto-routes to `bin/run-tests` in fl-gaf), `jest`, `vitest`, `python` (pytest, `justMyCode=false`), `rspec`, `minitest`, plus the **custom UI test adapter** in [`config/neotest-ui-tests.lua`](lua/config/neotest-ui-tests.lua) for fl-gaf webapp (`webapp/projects/*/ui-tests/src/*.spec.ts`).

PHP test infra (fl-gaf):
- `<leader>Tx` — `bin/run-tests setup` (spins up namespaced Docker silo, writes `.cache/gaf_session_<PID>`).
- `<leader>TX` — `bin/run-tests shutdown` (tears it down).
- Neotest invocations go through [`scripts/neotest-run-tests.sh`](scripts/neotest-run-tests.sh) which calls `bin/run-tests <relative-path> --filter ... SETUP=false`. Setup must be run explicitly first (or you get "Services are not running").

UI test runners (fl-gaf webapp) — eight Overseer templates in [`lua/overseer/template/user/ui_test_*.lua`](lua/overseer/template/user/) cover `ui:main` × `{watch}` × `{mobile}` × `{devtools}`. Invoke via `<leader>or`. They:
- Default `SPECS` env to `vim.fn.expand("%:t")` (current buffer's filename); pass blank to run the full suite.
- Auto-resolve the `webapp/` directory — works whether nvim's cwd is the repo root, a worktree, the webapp folder itself, or any subdir under those.
- Set `DEVTOOLS=true` for devtools variants (read by `webapp/projects/ui-tests-common/karma.conf.cjs`).

### Framework-specific
- `laravel.lua` — `laravel.nvim` + `blade-nav.nvim` (`gf` on Blade includes/components/routes). Activates only when `artisan` exists at root.
- `ror.lua` — `ror.nvim`, `vim-projectionist` (Rails heuristics), `vim-endwise`, **Herb LSP** (HTML+ERB language server, auto-enabled when `herb-language-server` on `$PATH`). Activates on `Gemfile` + `config/environment.rb`.
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
3. If the server needs project-specific settings, gate them on a path check (see how `basedpyright` handles `~/freelancer-dev/fl-gaf` `extraPaths`).

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

Edit the `linters_by_ft` block in `formatting.lua`. The current setup gates linters on Freelancer-project detection — if your linter should run everywhere, add it outside the `if in_freelancer` block.

### Add a treesitter parser

Append to the `ensure_installed` list in [`lua/plugins/treesitter.lua`](lua/plugins/treesitter.lua) and run `:TSUpdate`.

If the parser needs custom indent handling, add the filetype to `skip_ts_indent` so treesitter indent doesn't override the built-in.

### Add a treesitter injection

Place a `.scm` file under `queries/<lang>/injections.scm`. See [`queries/php/injections.scm`](queries/php/injections.scm) for the Blade-into-Livewire example.

```scm
; inherits: php_only
((text) @injection.content
  (#set! injection.language "blade")
  (#set! injection.combined))
```

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
Custom Overseer task templates, auto-discovered. Currently 9 templates: 8 fl-gaf UI test variants (`ui_test_*.lua`) plus `fli_provision.lua`. Each file returns a table with `name`, `builder()`, `params`, and `condition.callback`. The UI test templates share builder logic via [`lua/config/ui_test.lua`](lua/config/ui_test.lua) — `resolve_webapp_cwd()` walks up from cwd to find the `webapp/` directory so the templates work from any nvim cwd. Invoke via `<leader>or`.

### `queries/php/injections.scm`
Treesitter injection: highlights post-`?>` content of Livewire single-file PHP components as Blade. Add more injection rules by appending `((text) @injection.content (#set! injection.language "..."))` patterns or by adding `queries/<lang>/injections.scm` for other languages.

### `scripts/neotest-run-tests.sh`
PHPUnit wrapper for fl-gaf. Delegates to `bin/run-tests` (so namespacing via `GAF_TEST_WORKER_ID` and session-file lookup are handled upstream). Two transformations:
1. `--filter` value: spaces become `\s` (PCRE-equivalent) — survives `bin/run-tests`' `read -r -a flag_args <<< "$1"` word-split.
2. `--log-junit` path: redirected to `.cache/neotest-junit-$$.xml` (inside Docker bind-mount), then copied to neotest's tempfile after.

Test path is canonicalized via `realpath` and stripped to project-relative (`bin/run-tests` requires `^test/{functional,unit}` etc.). Always runs with `SETUP=false`, so containers must be brought up first via `<leader>Tx`. Works in both `fl-gaf/` and `fl-gaf-worktree/<branch>/` since each has its own `bin/run-tests`.

### `docs/keybinds.md`
Hand-maintained 150+ keybinding cheatsheet, grouped by category, with a `Source` column linking each binding back to the file that defines it. Update this when you add or move keymaps.

### `lazy-lock.json`
Plugin lockfile pinning all 106 plugins. Always commit after `:Lazy sync`.

---

## Project-Specific Behavior

This config detects a few project layouts and adjusts behavior automatically:

**Freelancer monorepo (`fl-gaf`)** — detected via path containing `freelancer-dev/fl-gaf`:
- PHP linters (`phpcs`, `phpstan`) enable with project configs (`phpcs_gaf.xml`, `phpstan.neon`)
- `php-cs-fixer` used instead of `pint`
- `basedpyright` adds `extraPaths` for `libgafthrift` and `restutils`
- `neotest-phpunit` routes through `bin/run-tests` Docker wrapper
- Custom UI test adapter activates for `webapp/projects/*/ui-tests/src/*.spec.ts`

**Phabricator** — `gx` on a `D####` or `T####` token opens `https://phabricator.tools.flnltd.com/<token>`.

**Laravel** — `laravel.nvim` activates only when `artisan` is in the project root.

**Rails** — `ror.nvim` + projectionist activate on `Gemfile` + `config/environment.rb`. REPL auto-prefers `bin/rails console` → `pry` → `irb`.

To remove project-specific behavior, search the codebase for `freelancer-dev` / `flnltd` and either remove or replace the gates.

---

## Ruby / Rails / ERB Snippets

All snippets ship via [`friendly-snippets`](https://github.com/rafamadriz/friendly-snippets) and surface through `blink.cmp`'s `snippets` source. Triggers are word-based — type the prefix, then `<Tab>` or `<CR>` accepts the highlighted match. blink.cmp does **not** auto-show the menu on symbol-only prefixes (`=`, `%`); use a word trigger (`pe`, `er`) for ERB output/exec tags.

To add custom snippets: `<leader>Sa` (scissors). To edit: `<leader>Se`.

### Plain Ruby (filetype `ruby`)

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
