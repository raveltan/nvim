return {
	{
		"mason-org/mason.nvim",
		cmd = "Mason",
		config = true,
	},

	{
		"mason-org/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		opts = function()
			-- PHP is deliberately absent: phpantom_lsp has no mason package, it comes
			-- from `brew install phpantom-lsp` and is enabled by hand below.
			local servers = {
				"vtsls",
				"eslint",
				"basedpyright",
				"ruff",
				"jsonls",
				"yamlls",
				"html",
				"cssls",
				"tailwindcss",
				"typos_lsp",
				"emmet_language_server",
				"lua_ls",
			}
			if vim.g.gaf then
				servers = require("gaf.lsp").filter_mason_servers(servers)
			end
			return { ensure_installed = servers }
		end,
	},

	-- Auto-install non-LSP tools (formatters, linters, DAP adapters not handled
	-- by mason-lspconfig/mason-nvim-dap). Runs on startup; updates on demand.
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "mason-org/mason.nvim" },
		-- cmd (not event): with run_on_start=false the plugin does nothing on
		-- file open, but its setup() probes mason-nvim-dap for name mappings and
		-- lazy.nvim's require-autoloader turns that pcall probe into a full load
		-- of the whole DAP stack (nvim-dap, dap-view, virtual-text, ...) on
		-- every first BufReadPre. Loading on the commands avoids that; the
		-- integration still works when :MasonToolsUpdate actually runs.
		cmd = {
			"MasonToolsInstall",
			"MasonToolsInstallSync",
			"MasonToolsUpdate",
			"MasonToolsUpdateSync",
			"MasonToolsClean",
		},
		opts = {
			-- The Laravel fallbacks are appended, not listed: GAF formats php with
			-- php_cs_fixer and lints with the monolith's own vendor/bin/phpcs, so pint,
			-- blade-formatter and phpstan are dead weight there. A Laravel project's
			-- own vendor/bin or node_modules/.bin always wins (lua/artisan/init.lua
			-- resolves in that order); these only make a freshly cloned project format
			-- and analyse before its dependencies are installed.
			ensure_installed = vim.list_extend({
				"stylua",
				"prettierd",
				"prettier",
			}, vim.g.gaf and {} or { "pint", "blade-formatter", "phpstan" }),
			auto_update = false,
			-- Don't probe the registry on load; run :MasonToolsUpdate manually.
			run_on_start = false,
		},
	},

	-- LSP config (needed for mason-lspconfig integration)
	{
		"neovim/nvim-lspconfig",
		-- Load before mason-lspconfig fires `vim.lsp.enable()` so vim.lsp.config()
		-- calls below register first. BufReadPre matches mason-lspconfig's event.
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "saghen/blink.cmp" },
		config = function()
			-- One global default for LSP capabilities (blink.cmp); per-server
			-- vim.lsp.config() tables below only override what they need.
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			vim.lsp.config("*", { capabilities = capabilities })

			-- Lua LSP for editing this config. lazydev.nvim feeds it the vim API +
			-- plugin types. stylua formatting stays opt-in per project (formatting.lua).
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						workspace = { checkThirdParty = false },
						telemetry = { enable = false },
					},
				},
			})

			-- TypeScript: vtsls (wraps the VS Code TS extension). Migrated from
			-- typescript-tools.nvim, which is in maintenance drift (its issue #273
			-- recommends vtsls). Same features, via LSP code actions + workspace
			-- commands — keymaps below.
			vim.lsp.config("vtsls", {
				settings = {
					typescript = {
						tsserver = { maxTsServerMemory = 8192 },
						preferences = {
							-- fl-gaf (GAF=1) bans relative @freelancer imports
							-- (eslint local-rules/validate-freelancer-imports) but still
							-- requires relative for self-imports within a @freelancer/ui
							-- package. project-relative satisfies both: alias across
							-- packages, relative within.
							importModuleSpecifier = vim.g.gaf and "project-relative" or "relative",
							includePackageJsonAutoImports = "auto",
						},
						updateImportsOnFileMove = { enabled = "always" },
					},
					javascript = {
						updateImportsOnFileMove = { enabled = "always" },
					},
				},
			})

			-- TS source actions + commands (were typescript-tools' TSTools*
			-- commands; vtsls exposes them as code-action kinds / workspace
			-- commands).
			local function ts_action(kind)
				return function()
					vim.lsp.buf.code_action({
						apply = true,
						context = { only = { kind }, diagnostics = {} },
					})
				end
			end
			local function ts_goto_source_definition()
				local client = vim.lsp.get_clients({ bufnr = 0, name = "vtsls" })[1]
				if not client then
					return
				end
				local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
				client:request("workspace/executeCommand", {
					command = "typescript.goToSourceDefinition",
					arguments = { params.textDocument.uri, params.position },
				}, function(err, locations)
					if err or not locations or vim.tbl_isempty(locations) then
						vim.notify("No source definition found", vim.log.levels.WARN)
						return
					end
					vim.lsp.util.show_document(locations[1], client.offset_encoding)
				end, 0)
			end
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("ts_source_actions", { clear = true }),
				pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
				callback = function(ev)
					local function bmap(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
					end
					bmap("<leader>co", ts_action("source.organizeImports"), "TS: organize imports")
					bmap("<leader>cM", ts_action("source.addMissingImports.ts"), "TS: add missing imports")
					bmap("<leader>cU", ts_action("source.removeUnusedImports"), "TS: remove unused imports")
					-- <leader>cx, not cR: angular/init.lua owns <leader>cR (goto_route)
					-- on typescript buffers.
					bmap("<leader>cx", ts_action("source.removeUnused.ts"), "TS: remove unused")
					bmap("<leader>cF", ts_action("source.fixAll.ts"), "TS: fix all")
					bmap("<leader>cD", ts_goto_source_definition, "TS: go to source definition")
				end,
			})

			-- ESLint
			vim.lsp.config("eslint", {
				settings = {
					run = "onSave",
					packageManager = "yarn",
				},
				flags = {
					allow_incremental_sync = false,
					debounce_text_changes = 1000,
				},
			})

			local basedpyright_analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				autoImportCompletions = true,
			}
			local basedpyright_config = {
				settings = {
					basedpyright = {
						analysis = basedpyright_analysis,
					},
				},
			}
			if vim.g.gaf then
				basedpyright_analysis.extraPaths = require("gaf.lsp").basedpyright_extra_paths()
				-- basedpyright defaults to "recommended" (its strictest mode), which
				-- floods legacy api-repo code; mypy-in-docker is the real type gate.
				basedpyright_analysis.typeCheckingMode = "standard"
				-- gaf_thrift-stubs use the legacy mypy stub convention (enum members
				-- annotated `X: int = ...`), which the current typing spec — and so
				-- pyright — reads as plain int attributes, not enum members. Every
				-- thrift exception/enum call site then false-errors. The thrift Iface
				-- multiple-inheritance pattern likewise trips override checks, and
				-- stub-only packages (six, grpc, gaf_thrift) warn about missing
				-- source. Silence just those classes; mypy-in-docker stays the gate.
				basedpyright_analysis.diagnosticSeverityOverrides = {
					reportArgumentType = "none",
					reportIncompatibleMethodOverride = "none",
					reportMissingModuleSource = "none",
					-- Warning not error: pyright infers unannotated legacy helpers'
					-- return types as unions (e.g. enterprise_utils' patch_filter_*
					-- isinstance branches), then flags attrs of the wrong union member.
					-- Real typos still show as yellow.
					reportAttributeAccessIssue = "warning",
					reportOptionalMemberAccess = "warning",
					reportOptionalOperand = "warning",
					reportOptionalIterable = "warning",
					reportOptionalSubscript = "warning",
				}
				-- Every api/ service dir has its own setup.py, which outranks .git in
				-- the default flat marker list and would root one server per service,
				-- breaking cross-service imports and relative extraPaths.
				-- Nested tables = priority order (0.11.3+): prefer .git so the
				-- monorepo roots once at the top.
				basedpyright_config.root_markers = {
					{ ".git" },
					{ "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json" },
				}
				-- Interpreter with the repo's third-party deps; only wired up when
				-- the venv actually exists so a fresh machine degrades gracefully to
				-- intra-repo + stub completion.
				local py = require("gaf.lsp").basedpyright_python_path()
				if vim.fn.executable(py) == 1 then
					basedpyright_config.settings.python = { pythonPath = py }
				end
			end
			vim.lsp.config("basedpyright", basedpyright_config)

			-- Ruff (lint + format + organize imports; defer hover to basedpyright)
			vim.lsp.config("ruff", {
				on_attach = function(client, _)
					client.server_capabilities.hoverProvider = false
				end,
			})

			-- PHPantom (PHP) — Rust server, replaces intelephense. Installed with
			-- `brew install phpantom-lsp` (no mason package), hence the executable
			-- guard and the manual vim.lsp.enable.
			--
			-- Nothing is passed as LSP `settings` on purpose: the server answers
			-- workspace/didChangeConfiguration with "not implemented" and reads
			-- `.phpantom.toml` instead — project root first, then
			-- ~/.config/phpantom_lsp/.phpantom.toml, project wins outright on any key
			-- it sets. `phpantom_lsp init` writes a commented default. So the old
			-- intelephense knobs have no counterpart here, and mostly no need for one:
			-- phpstorm-stubs are compiled into the binary (no `stubs` list to repeat),
			-- Laravel Eloquent/relations resolve natively (no ide-helper dependency),
			-- and indexing follows .gitignore rather than a glob exclude list. What
			-- remains tunable per repo is `[indexing] strategy` and the external-tool
			-- runners (`[phpstan]`, `[phpcs]`, `[mago]`).
			--
			-- Blade is deliberately absent from `filetypes`: the parser is PHP-only,
			-- so every @directive would be a syntax error. Blade's PHP-level
			-- intelligence comes from laravel_lsp below plus the html/emmet/tailwind
			-- servers.
			if vim.fn.executable("phpantom_lsp") == 1 then
				vim.lsp.config("phpantom_lsp", {
					filetypes = { "php" },
					-- Nested = priority order (0.11.3+): an explicit .phpantom.toml marks
					-- the intended root, then .git so the monorepo roots once at the repo
					-- top instead of at whichever nested composer.json is closest, which
					-- fragmented intelephense's index across sub-package workspaces.
					root_markers = { { ".phpantom.toml" }, { ".git" }, { "composer.json" } },
				})
				vim.lsp.enable("phpantom_lsp")
			end

			-- Laravel LSP — the first-party framework server (laravel/lsp, announced
			-- at Laracon US 2026). `composer global require laravel/lsp`; it is a PHAR
			-- on $PATH, has no mason package, and nvim-lspconfig ships no config for
			-- it, so both the name and the definition are ours. Do NOT call it
			-- `laravel_ls` — that name is taken upstream by an unrelated third-party
			-- Go server.
			--
			-- It layers *on top of* phpantom_lsp rather than replacing it: every
			-- provider resolves framework string literals (route/view/config/env/
			-- translation keys, component tags, middleware, gates, container
			-- bindings) and it advertises no rename, references, symbols or
			-- formatting. General PHP intelligence stays phpantom's job.
			--
			-- Unlike phpantom it *is* attached to blade, which is the whole point:
			-- `<x-`, `<livewire:`, `@directive`, `@include` and every helper string
			-- now answer inside a view.
			-- GAF-gated as well as executable-gated: fl-gaf is PHP but not Laravel, so
			-- there is nothing here for this server to answer. The root resolver below
			-- would already decline (no artisan file), but not registering the config
			-- keeps it out of :LspInfo and out of the php/blade attach path entirely.
			-- The interpreter is explicit: launched through the `php` on PATH (8.1 on
			-- this machine) the PHAR fails its own ^8.2.0 requirement check and exits 1
			-- before the handshake, which surfaces only as "laravel_lsp quit with exit
			-- code 1". No php >= 8.2 installed at all means no working server, so the
			-- config is not registered rather than registered and dead.
			local laravel_php = not vim.g.gaf and vim.fn.executable("laravel-lsp") == 1
				and require("artisan.lsp").php_82()
			if laravel_php then
				vim.lsp.config("laravel_lsp", {
					cmd = { laravel_php, vim.fn.exepath("laravel-lsp") },
					filetypes = { "php", "blade" },
					-- `artisan` only. The README also lists composer.json and .git, but
					-- the server hard-errors ("root URI must be a Laravel project") when
					-- the root it is handed has no artisan file — so the wider markers
					-- can only pick a root it will then refuse.
					--
					-- A resolver rather than root_markers: with markers, a php/blade buffer
					-- outside any artisan root still starts the server in single-file mode,
					-- and it rejects the handshake outright ("Initialize request must include
					-- a workspace root URI") — one error notification per such file. Leaving
					-- on_dir uncalled is how 0.12 says "no root, do not start".
					root_dir = function(bufnr, on_dir)
						local root = require("artisan").root(bufnr)
						if root then on_dir(root) end
					end,
					init_options = {
						-- Defaults to true and writes storage/framework/testing/_pest.php
						-- into the project. Pest completion here comes from LuaSnip.
						pestGenerateDocBlocks = true,
					},
					-- The server boots the app through `artisan tinker --execute` to read
					-- the route/config/view tables. Left at "auto" it probes Herd, Valet,
					-- Sail, Lando and DDEV to decide how; lua/artisan/ already resolves
					-- that from disk for conform/nvim-lint/dap, so hand it the answer.
					-- It has to happen here rather than in the static init_options above:
					-- one config serves every project opened in the session, and the
					-- environment is a property of the root, not of the editor.
					--
					-- Only "sail" and "local" are shared vocabulary. artisan.env()'s third
					-- answer, "docker", is a plain compose file with no sail wrapper —
					-- the server has no such mode, and naming one it doesn't know would
					-- be worse than letting it probe, so that case falls back to "auto".
					before_init = function(params, config)
						-- rootPath/rootUri are vim.NIL — userdata, NOT nil — when the server
						-- starts with no workspace folder (a php/blade file opened outside any
						-- artisan root). `root_dir or params.rootPath` therefore handed userdata
						-- to artisan.env(), which threw BEFORE_INIT_CALLBACK_ERROR out of
						-- BufReadPost. Keep only real strings; env(nil) re-resolves the root from
						-- the buffer's own dir.
						local root = type(config.root_dir) == "string" and config.root_dir
							or type(params.rootPath) == "string" and params.rootPath
							or nil
						local env = require("artisan").env(root)
						config.init_options = vim.tbl_extend("force", config.init_options or {}, {
							phpEnvironment = (env == "docker") and "auto" or env,
						})
					end,
				})
				vim.lsp.enable("laravel_lsp")
			end

			-- JSON LSP with SchemaStore catalog (package.json, tsconfig, composer.json, GH Actions, ...)
			vim.lsp.config("jsonls", {
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enable = true },
					},
				},
			})

			-- YAML LSP with SchemaStore catalog
			vim.lsp.config("yamlls", {
				settings = {
					yaml = {
						schemaStore = { enable = false, url = "" }, -- disable built-in; use SchemaStore.nvim instead
						schemas = require("schemastore").yaml.schemas(),
					},
				},
			})

			-- Tailwind CSS
			-- blade is included so Laravel views get class completion/hover/lint; the
			-- server only starts where a tailwind config exists, so non-Tailwind
			-- projects pay nothing for it being listed.
			local tailwind_class_regex = { { "@apply\\s+([^;]*)", "" } }
			if not vim.g.gaf then
				vim.list_extend(tailwind_class_regex, require("artisan.lsp").tailwind_class_regex)
			end
			vim.lsp.config("tailwindcss", {
				filetypes = { "html", "css", "javascript", "typescript", "javascriptreact", "typescriptreact", "blade" },
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = tailwind_class_regex,
						},
					},
				},
			})

			-- HTML LSP.
			-- autoClosingTags disabled: nvim-ts-autotag already handles close-tag insertion;
			-- leaving this on causes duplicate `</tag>` (one from autotag, one from LSP completion).
			-- blade is included so Laravel views still get tag/attribute completion
			-- and auto-closing hints. It parses @directives as text, which is
			-- harmless for completion — unlike a PHP server, it emits no diagnostics
			-- we'd have to suppress.
			vim.lsp.config("html", {
				filetypes = { "html", "blade" },
				init_options = {
					provideFormatter = false,
					configurationSection = { "html", "css", "javascript" },
					embeddedLanguages = { css = true, javascript = true },
				},
				settings = {
					html = {
						autoClosingTags = false,
					},
				},
			})

			-- CSS LSP — only on pure CSS files.
			vim.lsp.config("cssls", {
				filetypes = { "css", "scss", "less" },
			})

			-- Emmet abbreviation expansion (LSP). Replaces mattn/emmet-vim: there's no
			-- <plug> expand map anymore — abbreviations (`div>ul>li`, `.foo`, `!`) surface
			-- in the blink completion menu; accept to expand. svelte added to the server's
			-- default filetype set (defaults omit it).
			vim.lsp.config("emmet_language_server", {
				filetypes = {
					"html",
					"eruby",
					"blade",
					"css",
					"scss",
					"sass",
					"less",
					"javascriptreact",
					"typescriptreact",
					"vue",
					"svelte",
					"htmldjango",
				},
				init_options = {
					showExpandedAbbreviation = "always",
				},
			})

			-- Typos LSP — fast spell/typo checker (Rust). Hint severity to stay quiet.
			vim.lsp.config("typos_lsp", {
				init_options = {
					diagnosticSeverity = "Hint",
				},
			})

			-- Herb: HTML+ERB language server (parser, linter, formatter via LSP)
			-- Requires: npm install -g @herb-tools/language-server
			-- Docs: https://herb-tools.dev
			if vim.fn.executable("herb-language-server") == 1 then
				vim.lsp.config("herb_ls", {
					cmd = { "herb-language-server", "--stdio" },
					filetypes = { "eruby", "html" },
					root_markers = { "Gemfile", ".git" },
					on_attach = function(client, _)
						-- conform's erb_format owns ERB formatting (rails.lua); html goes
						-- through conform's prettier. Keep one formatting owner.
						client.server_capabilities.documentFormattingProvider = false
						client.server_capabilities.documentRangeFormattingProvider = false
					end,
				})
				vim.lsp.enable("herb_ls")
			end

			-- SourceKit (Swift) — ships with the Xcode toolchain, not mason.
			-- xcode-build-server (brew) generates buildServer.json so it understands
			-- .xcodeproj/.xcworkspace; plain SPM packages work out of the box.
			-- Build/run/test/debug live in xcodebuild.nvim (lua/plugins/swift.lua).
			if vim.fn.executable("sourcekit-lsp") == 1 then
				vim.lsp.config("sourcekit", {
					-- sourcekit relies on dynamically-registered file watching to pick up
					-- cross-file changes; the blink capabilities from the "*" default don't
					-- advertise it, so extend just that here -- vim.lsp.config deep-merges
					-- this onto the global capabilities.
					capabilities = {
						workspace = {
							didChangeWatchedFiles = { dynamicRegistration = true },
						},
					},
					-- Default filetypes also claim c/cpp/objc — keep it to swift only.
					filetypes = { "swift" },
				})
				vim.lsp.enable("sourcekit")
			end

			-- mason-lspconfig 2.x `automatic_enable=true` (default) enables every
			-- server in `ensure_installed` automatically — no manual vim.lsp.enable.

			vim.diagnostic.config({
				virtual_text = false, -- tiny-inline-diagnostic handles this
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.INFO] = " ",
						[vim.diagnostic.severity.HINT] = " ",
					},
				},
				underline = {
					severity = { min = vim.diagnostic.severity.HINT },
				},
				update_in_insert = false,
				float = { border = "rounded" },
				jump = { float = true },
				severity_sort = true,
			})

			-- Ensure diagnostic underlines work even when terminal lacks undercurl support
			for _, level in ipairs({ "Error", "Warn", "Info", "Hint", "Ok" }) do
				local hl = vim.api.nvim_get_hl(0, { name = "DiagnosticUnderline" .. level, link = false })
				if hl.undercurl and not hl.underline then
					hl.underline = true
					vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. level, hl)
				end
			end
		end,
	},

	-- LSP progress indicator
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {
			progress = {
				display = {
					render_limit = 5,
					done_ttl = 2,
				},
			},
			notification = {
				window = {
					winblend = 0, -- solid background for catppuccin
				},
			},
		},
	},

	-- LSP code action preview (diff before applying). Replaces <leader>ca.
	{
		"aznhe21/actions-preview.nvim",
		keys = {
			{
				"<leader>ca",
				function()
					require("actions-preview").code_actions()
				end,
				mode = { "n", "v" },
				desc = "Code action (preview)",
			},
		},
		opts = {},
	},

	-- Trouble
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		keys = {
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
		},
		config = true,
	},

	-- Lua LSP for Neovim config development
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},

	-- Snippet engine
	{
		"L3MON4D3/LuaSnip",
		version = "v2.*",
		build = "make install_jsregexp",
		dependencies = { "rafamadriz/friendly-snippets" },
		event = "InsertEnter", -- defer load; snippets only matter once typing starts
		config = function()
			local ls = require("luasnip")
			ls.config.setup({
				-- history=false + region_check on InsertEnter only: exited snippets die and
				-- are NOT re-armed when the cursor wanders back into an old region. Prevents
				-- <Tab> (blink default preset = snippet_forward) from teleporting into a stale
				-- snippet instead of indenting. CursorMoved region-checks were the cause.
				history = false,
				updateevents = "TextChanged,TextChangedI",
				region_check_events = "InsertEnter",
				delete_check_events = "TextChanged,InsertLeave",
				enable_autosnippets = false,
			})
			-- Pest snippets are registered under a synthetic `pest` filetype rather
			-- than `php`, and ft_func below adds that filetype only in buffers that
			-- belong to a Pest project. Registering them as `php` would put
			-- `it`/`test`/`describe` in the completion menu of every PHP buffer in
			-- every project for the rest of the session — LuaSnip's registry is
			-- global, so a load-once-on-demand approach leaks the same way.
			if not vim.g.gaf then
				local ft_from_filetype = require("luasnip.extras.filetype_functions").from_filetype
				require("luasnip").config.setup({
					ft_func = function()
						local filetypes = ft_from_filetype()
						if vim.bo.filetype == "php" and require("artisan.test").uses_pest() then
							filetypes[#filetypes + 1] = "pest"
						end
						return filetypes
					end,
				})
			end

			require("luasnip.loaders.from_vscode").lazy_load()
			require("luasnip.loaders.from_vscode").lazy_load({
				paths = { vim.fn.stdpath("config") .. "/snippets" },
			})
			-- Laravel 13 / Livewire 4 / Filament v5, kept in their own pack and out of
			-- the GAF profile: LuaSnip's registry is global and these register under
			-- plain `php`, so loading them in the monolith would put `lmodel`,
			-- `filres` and friends in the completion menu of every PHP buffer there.
			if not vim.g.gaf then
				require("luasnip.loaders.from_vscode").lazy_load({
					paths = { vim.fn.stdpath("config") .. "/snippets/laravel" },
				})
			end
			-- load(), not lazy_load(): lazy_load defers until a FileType event names
			-- the filetype, and `pest` is synthetic — no buffer ever has it, so the
			-- snippets would never arrive. Eager is fine here, it is 22 entries and
			-- LuaSnip itself only loads on InsertEnter.
			if not vim.g.gaf then
				require("luasnip.loaders.from_vscode").load({
					paths = { vim.fn.stdpath("config") .. "/snippets/pest" },
				})
			end
		end,
	},

	-- Autocomplete
	{
		"saghen/blink.cmp",
		event = "InsertEnter",
		version = "1.*",
		dependencies = { "rafamadriz/friendly-snippets", "L3MON4D3/LuaSnip" },
		---@type blink.cmp.Config
		opts = function()
			return {
				enabled = function()
					return vim.bo.filetype ~= "grug-far"
				end,
				keymap = {
					preset = "default",
					["<C-Space>"] = { "show", "hide", "show_documentation", "hide_documentation" },
					-- The default preset maps <Tab> to snippet_forward+fallback; neocursor
					-- wants the same key. Order matters: snippet_forward first so a live
					-- placeholder jump is never stolen by a Cursor Tab ghost, then neocursor
					-- (accept edit / jump to next edit / follow prediction — it returns false
					-- when nothing is pending), then a literal tab.
					["<Tab>"] = {
						"snippet_forward",
						function()
							-- package.loaded, not require: lazy.nvim resolves a require of an
							-- unloaded plugin's module by loading that plugin, which would boot
							-- neocursor (and its sidecar) outside the GAF profile that gates it.
							local neocursor = package.loaded["neocursor"]
							return neocursor ~= nil and neocursor.accept()
						end,
						"fallback",
					},
					["<CR>"] = {
						function(cmp)
							if cmp.is_visible() then
								return false
							end
							local line = vim.api.nvim_get_current_line()
							local col = vim.api.nvim_win_get_cursor(0)[2]
							local before = line:sub(col, col)
							local after = line:sub(col + 1, col + 1)
							local pair_map = { ["("] = ")", ["["] = "]", ["{"] = "}" }
							if pair_map[before] == after then
								vim.api.nvim_feedkeys(
									vim.api.nvim_replace_termcodes("<CR><C-o>O", true, true, true),
									"n",
									false
								)
								return true
							end
						end,
						"accept",
						"fallback",
					},
				},
				appearance = {
					nerd_font_variant = "mono",
					-- blink.cmp v1 ships a complete Nerd Font kind_icons set; no lspkind needed.
				},
				snippets = { preset = "luasnip" },
				completion = {
					accept = { resolve_timeout_ms = 500 },
					documentation = {
						auto_show = true,
						auto_show_delay_ms = 100,
						window = { border = "rounded", winblend = 0 },
					},
					-- Disabled: inline ghost text (virt_text_pos='inline' in ns blink_cmp)
					-- could orphan its extmark across buffer/redraw races, leaving stuck
					-- "typed" text that can't be deleted and isn't undoable.
					ghost_text = { enabled = false },
					-- Explicitly pin trigger behavior. Defaults should match this but
					-- pinning rules out a default drift across blink versions.
					trigger = {
						show_on_keyword = true,
						show_on_trigger_character = true,
						show_on_insert_on_trigger_character = true,
					},
					menu = {
						auto_show = true,
						border = "rounded",
						winblend = 0,
						scrollbar = false,
						draw = {
							treesitter = { "lsp" },
							columns = {
								{ "kind_icon", "label", "label_description", gap = 1 },
								{ "kind", gap = 1 },
							},
							components = {
								kind_icon = {
									text = function(ctx)
										return " " .. ctx.kind_icon .. ctx.icon_gap .. " "
									end,
									highlight = function(ctx)
										return "BlinkCmpKind" .. ctx.kind
									end,
								},
								kind = {
									highlight = function(ctx)
										return "BlinkCmpKind" .. ctx.kind
									end,
								},
							},
						},
					},
					list = { selection = { preselect = true, auto_insert = false } },
				},
				signature = { enabled = true, window = { border = "rounded" } },
				sources = (function()
					local sources = {
						default = { "lsp", "path", "snippets", "buffer" },
						-- blink does not consult omnifunc, so dadbod-completion must be
						-- registered as a native source for SQL filetypes.
						per_filetype = {
							sql = { "dadbod", "snippets", "buffer" },
							mysql = { "dadbod", "snippets", "buffer" },
							plsql = { "dadbod", "snippets", "buffer" },
							-- Angular inline-template @Input/@Output completion (see
							-- lua/angular/inputs_source.lua) on top of the normal TS sources.
							typescript = { "angular_inputs", "lsp", "path", "snippets", "buffer" },
						},
						providers = {
							lsp = { max_items = 50 },
							dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
							angular_inputs = {
								name = "Angular",
								module = "angular.inputs_source",
								-- Float component inputs above generic LSP/buffer noise when the
								-- cursor is actually inside a component tag.
								score_offset = 5,
							},
						},
					}

					-- php and blade have no entry here and use `default`, where `lsp` means
					-- laravel_lsp plus phpantom_lsp (php) or html/emmet/tailwind (blade).
					-- The language servers own Laravel completion outright.

					return sources
				end)(),
				fuzzy = { implementation = "prefer_rust" },
			}
		end,
	},
}
