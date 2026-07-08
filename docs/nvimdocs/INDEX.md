# INDEX

Master index of every doc in `docs/nvimdocs/`, grouped by category. One line per entry.

## Config

- [config-init](config-init.md) — `init.lua` bootstrap order + `vim.g.gaf` env flag
- [config-options](config-options.md) — `vim.opt` defaults, leader keys, providers
- [config-lazy](config-lazy.md) — lazy.nvim bootstrap + `plugins/` auto-import
- [config-keymaps](config-keymaps.md) — global plugin-agnostic keymaps
- [config-rename](config-rename.md) — smart `<leader>cr`: CSS class (cross-file, scss `&`-aware) → tag pair → LSP
- [config-autocmds](config-autocmds.md) — autocmd groups + LSP hover patch
- [config-profile](config-profile.md) — startup profiling helper
- [config-neotest-coverage](config-neotest-coverage.md) — PHP/Ruby neotest run-with-coverage helper
- [config-neotest-profile-ruby](config-neotest-profile-ruby.md) — Ruby profile runner
- [config-neotest-profile-ts](config-neotest-profile-ts.md) — TS profile runner

## GAF (Freelancer)

- [gaf-overview](gaf-overview.md) — what `GAF=1` unlocks + feature matrix
- [gaf-readme](gaf-readme.md) — workflow cheatsheet (PHPUnit, xdebug, UI tests)
- [gaf-paths](gaf-paths.md) — devbox name + fl-gaf root + `/mnt/gaf` constants
- [gaf-keymaps](gaf-keymaps.md) — `gx` on `D####`/`T####` Phabricator opener
- [gaf-lsp](gaf-lsp.md) — basedpyright extra paths + tailwindcss filter
- [gaf-dap](gaf-dap.md) — PHP xdebug DAP config + path mappings
- [gaf-functional-debug](gaf-functional-debug.md) — step-debug functional tests: LOCAL vs DEVBOX, which xdebug config to pick
- [gaf-xdebug](gaf-xdebug.md) — `:GafXdebug*` port-forward / profile commands
- [gaf-test](gaf-test.md) — neotest extension routing phpunit via fl-gaf
- [gaf-test-infra](gaf-test-infra.md) — `bin/run-tests setup/shutdown` wrappers
- [gaf-neotest-profile](gaf-neotest-profile.md) — `XDEBUG_MODE=profile` runner
- [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md) — `yarn ui:<project>` neotest adapter
- [gaf-ui-test](gaf-ui-test.md) — overseer template helper for UI tests
- [gaf-formatting](gaf-formatting.md) — php-cs-fixer + phpcs against fl-gaf rulesets

## LSP

- [lsp-mason](lsp-mason.md) — Mason tool installer / `:Mason` UI
- [lsp-mason-lspconfig](lsp-mason-lspconfig.md) — server ensure_installed bridge
- [lsp-mason-tool-installer](lsp-mason-tool-installer.md) — non-LSP tool install via `:MasonTools*`
- [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md) — server configs (basedpyright, intelephense, ...)
- [lsp-actions-preview](lsp-actions-preview.md) — diff preview for code actions
- [lsp-fidget](lsp-fidget.md) — LSP progress notifier
- [lsp-lazydev](lsp-lazydev.md) — Lua LSP awareness for `vim.*` API
- [lsp-trouble](lsp-trouble.md) — diagnostics panel

## Completion

- [cmp-blink](cmp-blink.md) — blink.cmp completion engine
- [cmp-luasnip](cmp-luasnip.md) — LuaSnip snippet engine + paths
- [snippets-dir](snippets-dir.md) — `~/.config/nvim/snippets/` JSON snippet pack

## Treesitter

- [ts-nvim-treesitter](ts-nvim-treesitter.md) — parsers + highlight + indent
- [ts-context](ts-context.md) — sticky context header
- [ts-textobjects](ts-textobjects.md) — textobject queries + `]f`/`[f` motions + arg swap
- [ts-autotag](ts-autotag.md) — HTML/JSX auto close/rename tags

## DAP

- [dap-nvim-dap](dap-nvim-dap.md) — core debug adapter protocol client
- [dap-nvim-dap-view](dap-nvim-dap-view.md) — tabbed UI panel
- [dap-nvim-dap-ruby](dap-nvim-dap-ruby.md) — rdbg adapter for Ruby
- [dap-mason-nvim-dap](dap-mason-nvim-dap.md) — Mason → DAP adapter bridge
- [dap-virtual-text](dap-virtual-text.md) — inline variable values
- [dap-persistent-breakpoints](dap-persistent-breakpoints.md) — save/load BPs across sessions
- [dap-goto-breakpoints](dap-goto-breakpoints.md) — `]b`/`[b` next/prev breakpoint

## Test

- [test-neotest](test-neotest.md) — neotest core + key bindings
- [test-neotest-adapters](test-neotest-adapters.md) — phpunit / jest / vitest / pytest / rspec / minitest

## Coverage

- [coverage](coverage.md) — nvim-coverage gutter signs (SimpleCov / cobertura)

## Debug + Coverage (per-language)

- [php-debug-coverage](php-debug-coverage.md) — xdebug DAP + cobertura (GAF-gated)
- [ruby-debug-coverage](ruby-debug-coverage.md) — rdbg + SimpleCov
- [python-debug-coverage](python-debug-coverage.md) — debugpy + pytest-cov
- [typescript-debug-coverage](typescript-debug-coverage.md) — pwa-node/chrome + jest/vitest lcov
- [rust-debug-coverage](rust-debug-coverage.md) — codelldb + cargo-llvm-cov
- [flutter-debug-coverage](flutter-debug-coverage.md) — Dart/Flutter debug + lcov coverage

## Format / Lint

- [format-conform](format-conform.md) — formatters_by_ft + format-on-save
- [format-nvim-lint](format-nvim-lint.md) — linters_by_ft (extends under GAF)

## Snacks

- [snacks-core](snacks-core.md) — module enable matrix + global setup
- [snacks-picker](snacks-picker.md) — files / grep / LSP / diagnostics pickers
- [snacks-dashboard](snacks-dashboard.md) — startup dashboard
- [snacks-misc](snacks-misc.md) — terminal / lazygit / notifier / indent / words / rename

## Editor

- [editor-which-key](editor-which-key.md) — leader prefix labels
- [editor-textobjects-cheatsheet](editor-textobjects-cheatsheet.md) — master textobject + motion + surround guide
- [editor-mini-ai](editor-mini-ai.md) — extended textobjects
- [editor-mini-surround](editor-mini-surround.md) — `gs*` surround ops
- [editor-tagmatch](editor-tagmatch.md) — treesitter `%` tag jump, `i%`/`a%` objects, tag rename (in-repo `lua/tagmatch/`)
- [editor-angular](editor-angular.md) — Angular component nav: `gd` on tags/attrs/classes/routes, `<leader>c{p,G,R}`, blink @Input/@Output completion inside tags (in-repo `lua/angular/`)
- [editor-mini-bufremove](editor-mini-bufremove.md) — `<leader>bd` close-keep-window
- [editor-flash](editor-flash.md) — `s`/`S` label jumps
- [editor-grug-far](editor-grug-far.md) — project-wide find/replace UI
- [editor-folding](editor-folding.md) — nvim-ufo folding (LSP + treesitter, peek, fold-to-level)
- [editor-undotree](editor-undotree.md) — undo history
- [editor-marks](editor-marks.md) — mark gutter + picker
- [editor-yanky](editor-yanky.md) — yank ring
- [editor-dial](editor-dial.md) — extended `<C-a>`/`<C-x>` (dates, bools, ...)
- [editor-vim-abolish](editor-vim-abolish.md) — **removed** — was: `cr*` case coercion + `:S` substitute
- [editor-vim-repeat](editor-vim-repeat.md) — `.` plugin-action repeat support
- [editor-vim-sleuth](editor-vim-sleuth.md) — auto-detect indent/tabs
- [editor-vim-matchup](editor-vim-matchup.md) — extended `%` matching
- [editor-ultimate-autopair](editor-ultimate-autopair.md) — bracket / quote autopair
- [editor-ts-comments](editor-ts-comments.md) — context-aware comments
- [editor-scissors](editor-scissors.md) — `<leader>S*` snippet edit/add
- [editor-checkmate](editor-checkmate.md) — **removed** — was: markdown todo plugin (owns `<leader>t*` in md)
- [editor-todo-comments](editor-todo-comments.md) — TODO/FIXME highlight + picker
- [editor-hlslens](editor-hlslens.md) — search match count + virt text
- [editor-highlight-undo](editor-highlight-undo.md) — flash region on undo/redo
- [editor-refjump](editor-refjump.md) — **removed** — was: `]r`/`[r` LSP reference cycle
- [editor-dropbar](editor-dropbar.md) — **removed** — was: winbar breadcrumb picker `<leader>;`
- [editor-bqf](editor-bqf.md) — **removed** — was: better quickfix preview
- [editor-quicker](editor-quicker.md) — editable quickfix
- [editor-obsidian](editor-obsidian.md) — obsidian vault integration

## Navigation

- [nav-oil](nav-oil.md) — file explorer (`<leader>e`, `-` parent)
- [nav-harpoon](nav-harpoon.md) — pinned files (`<leader>1`–`8`)
- [nav-fff](nav-fff.md) — alt file finder
- [nav-seeker](nav-seeker.md) — progressive file→grep seeker (`<leader>/`, `<C-e>` toggle)
- [nav-vim-tmux-navigator](nav-vim-tmux-navigator.md) — `<C-h/j/k/l>` window + pane

## Git

- [git-gitsigns](git-gitsigns.md) — gutter signs + hunk preview/reset
- [git-conflict](git-conflict.md) — merge conflict resolver
- [git-fugitive](git-fugitive.md) — `:Gdiffsplit` + line/file history (`:Gedit`)

## UI

- [ui-lualine](ui-lualine.md) — statusline
- [ui-noice](ui-noice.md) — cmdline + LSP hover/messages
- [ui-gruvbox-baby](ui-gruvbox-baby.md) — **removed** — was: colorscheme option
- [ui-mini-icons](ui-mini-icons.md) — icon provider
- [ui-mini-indentscope](ui-mini-indentscope.md) — indent scope highlight
- [ui-colorizer](ui-colorizer.md) — inline color preview
- [ui-rainbow-delimiters](ui-rainbow-delimiters.md) — bracket pair coloring
- [ui-tiny-inline-diagnostic](ui-tiny-inline-diagnostic.md) — inline diagnostic renderer
- [ui-hlargs](ui-hlargs.md) — highlight function args
- [ui-satellite](ui-satellite.md) — scrollbar
- [ui-edgy](ui-edgy.md) — sidebar window manager
- [ui-duck](ui-duck.md) — terminal duck mascot

## Productivity

- [prod-typescript-tools](prod-typescript-tools.md) — TS LSP w/ source actions
- [prod-dadbod](prod-dadbod.md) — DB client (`<leader>D*`)
- [prod-redash](prod-redash.md) — Redash HTTP SQL client (`<leader>r*`, GAF=1)
- [prod-kulala](prod-kulala.md) — REST/HTTP client for `.http`/`.rest` files (`<leader>R*`)
- [prod-template-string](prod-template-string.md) — `"..."` → `` `...` `` on `${`

## Workflow

- [workflow-overseer](workflow-overseer.md) — task runner + auto-discovered templates
- [workflow-claude-code](workflow-claude-code.md) — **removed** — was: Claude Code terminal toggle
- [workflow-other](workflow-other.md) — related-file picker for PHP + Angular (`<leader>o{o,s,v}`); Rails nav delegated to vim-rails
- [workflow-emmet](workflow-emmet.md) — **removed** — was: `<C-y>,` HTML/CSS expansion
- [workflow-scripts](workflow-scripts.md) — `scripts/` helper shell scripts
- [workflow-silicon](workflow-silicon.md) — code → image screenshot

## Ruby / Rails

- [ruby-vim-rails](ruby-vim-rails.md) — Rails nav owner: `:A`/`:R`/`:E*` + projections (Avo, Turbo, FactoryBot, policy/serializer/decorator/form)
- [ruby-vim-endwise](ruby-vim-endwise.md) — auto-`end` for Ruby/Lua/Vim/Bash
- [ruby-conform-rubocop](ruby-conform-rubocop.md) — RuboCop formatter integration

## Rust

- [rust-rustaceanvim](rust-rustaceanvim.md) — Rust LSP + DAP + cargo runner

## Flutter

- [flutter-tools](flutter-tools.md) — Flutter / Dart LSP + emulator + hot reload

## Swift

- [swift-xcodebuild](swift-xcodebuild.md) — Xcode build/run/test/debug + SwiftUI previews; sourcekit-lsp via xcode-build-server

## Diagram

- [diagram-nvim](diagram-nvim.md) — **removed** — was: Mermaid/PlantUML/D2/Gnuplot inline render
- [diagram-image-nvim](diagram-image-nvim.md) — **removed** — was: Kitty image protocol backend
- [markview](markview.md) — **removed** — was: markdown rendering (`<leader>uM`)

## Ftplugin

- [ftplugin-php](ftplugin-php.md) — PHP `$$` → `$this->` + native LSP rename

## Util

- [util-line-history](util-line-history.md) — per-line & per-file git history picker
- [util-obsidian](util-obsidian.md) — obsidian.nvim utilities

## Docs

- [docs-nvimdocs](docs-nvimdocs.md) — how this doc set is structured
- [docs-devdocs](docs-devdocs.md) — devdocs.io integration
- [INDEX](INDEX.md) — this file

## Notes

- Regenerate this index after adding new docs — categories are by filename prefix.
- For the canonical hand-maintained keybind cheatsheet see `docs/keybinds.md` (one level up).
