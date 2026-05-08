local in_freelancer = vim.fn.getcwd():find(vim.fn.expand("~/freelancer-dev"), 1, true) ~= nil

return {
  -- Mason
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
      -- Gate tailwindcss out of ensure_installed when in freelancer (defeats the
      -- prior `vim.lsp.enable` gate that didn't actually prevent install/enable).
      local servers = { "eslint", "basedpyright", "ruff", "jsonls", "yamlls", "html", "cssls", "intelephense" }
      if not in_freelancer then
        table.insert(servers, "tailwindcss")
      end
      return { ensure_installed = servers }
    end,
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

      -- TypeScript is handled by typescript-tools.nvim (see productivity.lua).

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

      -- basedpyright (community fork of pyright with stronger inference)
      local basedpyright_analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        autoImportCompletions = true,
      }
      if in_freelancer then
        basedpyright_analysis.extraPaths = { "libgafthrift", "restutils" }
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

      -- Intelephense (PHP) — replaces phpantom
      vim.lsp.config("intelephense", {
        capabilities = capabilities,
        filetypes = { "php", "blade" },
        root_markers = { "composer.json", ".git" },
        settings = {
          intelephense = {
            files = {
              maxSize = 5000000,
              associations = { "*.php", "*.blade.php" },
            },
          },
        },
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

      -- Tailwind CSS (used with Livewire/Blade views)
      vim.lsp.config("tailwindcss", {
        capabilities = capabilities,
        filetypes = { "html", "css", "blade", "php", "javascript", "typescript", "javascriptreact", "typescriptreact" },
        settings = {
          tailwindCSS = {
            includeLanguages = {
              blade = "html",
            },
            experimental = {
              classRegex = {
                { "@apply\\s+([^;]*)", "" },
              },
            },
          },
        },
      })

      -- HTML LSP — extended to blade/php; let blade-formatter own formatting.
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

      -- CSS LSP — only on pure CSS files. Do NOT attach to blade: cssls treats
      -- the whole buffer as CSS, polluting completions and breaking formatting.
      -- Embedded <style> blocks in blade get syntax highlighting via treesitter injections.
      vim.lsp.config("cssls", {
        capabilities = capabilities,
        filetypes = { "css", "scss", "less" },
      })

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

  -- Incremental LSP rename with live preview
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    config = true,
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

  -- Autocomplete
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    ---@type blink.cmp.Config
    opts = {
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
      appearance = { nerd_font_variant = "mono" },
      snippets = {
        -- Wrap snippet expansion to gracefully handle broken snippets (e.g. blade loop first/last)
        expand = function(snippet)
          local ok, err = pcall(vim.snippet.expand, snippet)
          if not ok then
            -- Fall back to inserting the snippet as plain text
            vim.notify("Snippet parse error: " .. tostring(err), vim.log.levels.WARN)
            local cursor = vim.api.nvim_win_get_cursor(0)
            vim.api.nvim_put({ snippet }, "c", true, true)
          end
        end,
      },
      completion = {
        accept = { resolve_timeout_ms = 500 },
        documentation = { auto_show = true },
      },
      signature = { enabled = true },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "blade-nav" },
        per_filetype = {
          blade = { "blade-nav", "lsp", "path", "snippets", "buffer" },
          php = { "blade-nav", "lsp", "path", "snippets", "buffer" },
        },
        providers = {
          lsp = { max_items = 50 },
          ["blade-nav"] = { module = "blade-nav.blink", name = "blade-nav" },
          snippets = {
            opts = {
              search_paths = {
                vim.fn.stdpath("data") .. "/lazy/friendly-snippets",
                vim.fn.stdpath("config") .. "/snippets",
              },
            },
          },
        },
      },
      fuzzy = { implementation = "prefer_rust" },
    },
  },
}
