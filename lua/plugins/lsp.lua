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
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "vtsls", "eslint", "pyright", "tailwindcss" },
    },
  },

  -- LSP config (needed for mason-lspconfig integration)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- TypeScript (vtsls - faster, better auto-imports than ts_ls)
      -- Override root_dir to nil so root_markers is actually used
      -- (base vtsls config defines root_dir as a function which makes root_markers dead code)
      vim.lsp.config("vtsls", {
        capabilities = capabilities,
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { "tsconfig.json", "package.json" })
          on_dir(root or vim.fn.getcwd())
        end,
        settings = {
          vtsls = {
            autoUseWorkspaceTsdk = true,
          },
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              completeFunctionCalls = true,
              autoImports = true,
            },
            preferences = {
              importModuleSpecifier = "relative",
              includePackageJsonAutoImports = "auto",
            },
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
          javascript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              completeFunctionCalls = true,
              autoImports = true,
            },
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
            },
          },
        },
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

      -- Pyright
      local pyright_analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        autoImportCompletions = true,
      }
      if in_freelancer then
        pyright_analysis.extraPaths = { "libgafthrift", "restutils" }
      end
      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          python = {
            analysis = pyright_analysis,
          },
        },
      })

      -- Phpantom (PHP)
      vim.lsp.config("phpantom", {
        capabilities = capabilities,
        cmd = { vim.fn.expand("~/libs/bin/phpantom_lsp") },
        filetypes = { "php" },
        root_markers = { "composer.json", ".git" },
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

      vim.lsp.enable({ "vtsls", "eslint", "pyright", "phpantom", "tailwindcss" })

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
      keymap = {
        preset = "default",
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
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = { max_items = 50 },
        },
      },
      fuzzy = { implementation = "prefer_rust" },
    },
  },
}
