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
      local servers = { "vtsls", "eslint", "basedpyright", "ruff", "jsonls", "yamlls", "html", "cssls", "intelephense", "tailwindcss", "typos_lsp", "emmet_language_server" }
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
    cmd = { "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate", "MasonToolsUpdateSync", "MasonToolsClean" },
    opts = {
      ensure_installed = {
        "stylua",
        "prettierd",
        "prettier",
      },
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
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- TypeScript: vtsls (wraps the VS Code TS extension). Migrated from
      -- typescript-tools.nvim, which is in maintenance drift (its issue #273
      -- recommends vtsls). Same features, via LSP code actions + workspace
      -- commands — keymaps below.
      vim.lsp.config("vtsls", {
        capabilities = capabilities,
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
        if not client then return end
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
          bmap("<leader>co", ts_action("source.organizeImports"),      "TS: organize imports")
          bmap("<leader>cM", ts_action("source.addMissingImports.ts"), "TS: add missing imports")
          bmap("<leader>cU", ts_action("source.removeUnusedImports"),  "TS: remove unused imports")
          -- <leader>cx, not cR: angular/init.lua owns <leader>cR (goto_route)
          -- on typescript buffers.
          bmap("<leader>cx", ts_action("source.removeUnused.ts"),      "TS: remove unused")
          bmap("<leader>cF", ts_action("source.fixAll.ts"),            "TS: fix all")
          bmap("<leader>cD", ts_goto_source_definition,                "TS: go to source definition")
        end,
      })

      -- ESLint
      vim.lsp.config("eslint", {
        capabilities = capabilities,
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
      if vim.g.gaf then
        basedpyright_analysis.extraPaths = require("gaf.lsp").basedpyright_extra_paths()
      end
      vim.lsp.config("basedpyright", {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = basedpyright_analysis,
          },
        },
      })

      -- Ruff (lint + format + organize imports; defer hover to basedpyright)
      vim.lsp.config("ruff", {
        capabilities = capabilities,
        on_attach = function(client, _)
          client.server_capabilities.hoverProvider = false
        end,
      })

      -- Intelephense (PHP)
      -- Premium licence auto-discovered from ~/intelephense/licence.txt — no
      -- licenceKey init_option needed.
      vim.lsp.config("intelephense", {
        capabilities = capabilities,
        filetypes = { "php" },
        -- Node heap cap, same idea as tsserver_max_memory=8192 for TS: the
        -- default ~4GB heap can OOM indexing fl-gaf.
        cmd_env = { NODE_OPTIONS = "--max-old-space-size=8192" },
        -- Nested = priority order (0.11.3+): prefer .git so the monorepo roots
        -- once at the repo top instead of at whichever nested composer.json is
        -- closest, which fragmented the index across sub-package workspaces.
        root_markers = { { ".git" }, { "composer.json" } },
        settings = {
          intelephense = {
            files = {
              maxSize = 5000000,
              associations = { "*.php" },
              exclude = {
                -- Do NOT blanket-exclude vendor/ — that kills third-party symbol
                -- resolution (Symfony AbstractController, Route, Request, etc).
                -- Only trim vendor test dirs + nested vendor, matching intelephense defaults.
                "**/vendor/**/{Tests,tests}/**",
                "**/vendor/**/vendor/**",
                "**/node_modules/**",
                "**/.git/**",
                "**/storage/**",
                "**/.cache/**",
                "**/coverage/**",
              },
            },
          },
        },
        on_attach = function(client, _)
          -- Disable prepareRename: intelephense's prepare range is unreliable on `$var`.
          -- Raw rename request (see <leader>cr in keymaps.lua) handles position correctly.
          if client.server_capabilities.renameProvider then
            client.server_capabilities.renameProvider = { prepareProvider = false }
          end
        end,
      })

      -- JSON LSP with SchemaStore catalog (package.json, tsconfig, composer.json, GH Actions, ...)
      vim.lsp.config("jsonls", {
        capabilities = capabilities,
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      -- YAML LSP with SchemaStore catalog
      vim.lsp.config("yamlls", {
        capabilities = capabilities,
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" }, -- disable built-in; use SchemaStore.nvim instead
            schemas = require("schemastore").yaml.schemas(),
          },
        },
      })

      -- Tailwind CSS
      vim.lsp.config("tailwindcss", {
        capabilities = capabilities,
        filetypes = { "html", "css", "javascript", "typescript", "javascriptreact", "typescriptreact" },
        settings = {
          tailwindCSS = {
            experimental = {
              classRegex = {
                { "@apply\\s+([^;]*)", "" },
              },
            },
          },
        },
      })

      -- HTML LSP.
      -- autoClosingTags disabled: nvim-ts-autotag already handles close-tag insertion;
      -- leaving this on causes duplicate `</tag>` (one from autotag, one from LSP completion).
      vim.lsp.config("html", {
        capabilities = capabilities,
        filetypes = { "html" },
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
        capabilities = capabilities,
        filetypes = { "css", "scss", "less" },
      })

      -- Emmet abbreviation expansion (LSP). Replaces mattn/emmet-vim: there's no
      -- <plug> expand map anymore — abbreviations (`div>ul>li`, `.foo`, `!`) surface
      -- in the blink completion menu; accept to expand. svelte added to the server's
      -- default filetype set (defaults omit it).
      vim.lsp.config("emmet_language_server", {
        capabilities = capabilities,
        filetypes = {
          "html", "eruby", "css", "scss", "sass", "less",
          "javascriptreact", "typescriptreact", "vue", "svelte", "htmldjango",
        },
        init_options = {
          showExpandedAbbreviation = "always",
        },
      })

      -- Typos LSP — fast spell/typo checker (Rust). Hint severity to stay quiet.
      vim.lsp.config("typos_lsp", {
        capabilities = capabilities,
        init_options = {
          diagnosticSeverity = "Hint",
        },
      })

      -- Herb: HTML+ERB language server (parser, linter, formatter via LSP)
      -- Requires: npm install -g @herb-tools/language-server
      -- Docs: https://herb-tools.dev
      if vim.fn.executable("herb-language-server") == 1 then
        vim.lsp.config("herb_ls", {
          capabilities = capabilities,
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
          -- cross-file changes; blink's capabilities don't advertise it.
          capabilities = vim.tbl_deep_extend("force", {}, capabilities, {
            workspace = {
              didChangeWatchedFiles = { dynamicRegistration = true },
            },
          }),
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
      { "<leader>ca", function() require("actions-preview").code_actions() end, mode = { "n", "v" }, desc = "Code action (preview)" },
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
      require("luasnip.loaders.from_vscode").lazy_load()
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/snippets" },
      })
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
        ["<CR>"] = {
          function(cmp)
            if cmp.is_visible() then return false end
            local line = vim.api.nvim_get_current_line()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before = line:sub(col, col)
            local after = line:sub(col + 1, col + 1)
            local pair_map = { ["("] = ")", ["["] = "]", ["{"] = "}" }
            if pair_map[before] == after then
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR><C-o>O", true, true, true), "n", false)
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
                text = function(ctx) return " " .. ctx.kind_icon .. ctx.icon_gap .. " " end,
                highlight = function(ctx) return "BlinkCmpKind" .. ctx.kind end,
              },
              kind = {
                highlight = function(ctx) return "BlinkCmpKind" .. ctx.kind end,
              },
            },
          },
        },
        list = { selection = { preselect = true, auto_insert = false } },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        -- blink does not consult omnifunc, so dadbod-completion must be
        -- registered as a native source for SQL filetypes.
        per_filetype = {
          sql   = { "dadbod", "snippets", "buffer" },
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
      },
      fuzzy = { implementation = "prefer_rust" },
      }
    end,
  },
}
