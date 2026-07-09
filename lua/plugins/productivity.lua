return {
  -- TypeScript LSP: faster than vtsls/ts_ls, TS-specific commands
  -- Ports settings from the previous vtsls config in lsp.lua
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {
      settings = {
        tsserver_max_memory = 8192,
        tsserver_file_preferences = {
          -- fl-gaf (GAF=1) bans relative @freelancer imports
          -- (eslint local-rules/validate-freelancer-imports) but still requires
          -- relative for self-imports within a @freelancer/ui package.
          -- project-relative satisfies both: alias across packages, relative within.
          -- vim.g.gaf is set in init.lua before lazy reads this spec.
          importModuleSpecifierPreference = vim.g.gaf and "project-relative" or "relative",
          includePackageJsonAutoImports = "auto",
          includeInlayParameterNameHints = "none",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = false,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = false,
          includeInlayEnumMemberValueHints = false,
        },
        tsserver_format_options = {
          allowIncompleteCompletions = false,
          allowRenameOfImportPath = false,
        },
        expose_as_code_action = { "fix_all", "add_missing_imports", "remove_unused" },
        complete_function_calls = false,
        include_completions_with_insert_text = true,
        code_lens = "off",
        disable_member_code_lens = true,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        callback = function(ev)
          local opts = { buffer = ev.buf, silent = true }
          local map = vim.keymap.set
          map("n", "<leader>co", "<cmd>TSToolsOrganizeImports<cr>",      vim.tbl_extend("force", opts, { desc = "TS: organize imports" }))
          map("n", "<leader>cM", "<cmd>TSToolsAddMissingImports<cr>",    vim.tbl_extend("force", opts, { desc = "TS: add missing imports" }))
          map("n", "<leader>cU", "<cmd>TSToolsRemoveUnusedImports<cr>",  vim.tbl_extend("force", opts, { desc = "TS: remove unused imports" }))
          map("n", "<leader>cR", "<cmd>TSToolsRemoveUnused<cr>",         vim.tbl_extend("force", opts, { desc = "TS: remove unused" }))
          map("n", "<leader>cF", "<cmd>TSToolsFixAll<cr>",               vim.tbl_extend("force", opts, { desc = "TS: fix all" }))
          map("n", "<leader>cD", "<cmd>TSToolsGoToSourceDefinition<cr>", vim.tbl_extend("force", opts, { desc = "TS: go to source definition" }))
        end,
      })
    end,
  },

  -- Auto-convert "..." to `...` when typing ${
  {
    "axelvc/template-string.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {
      filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      jsx_brackets = true,
      remove_template_string = true,
    },
  },

  -- JSON/YAML schemas: package.json, tsconfig, composer.json, GitHub Actions, etc.
  -- Consumed by jsonls/yamlls in lsp.lua
  { "b0o/SchemaStore.nvim", lazy = true, version = false },

  -- Database client: connect/inspect/query Postgres/MySQL/SQLite from inside nvim.
  -- vim-dadbod is the engine, dadbod-ui is the file-tree UI, dadbod-completion
  -- gives column/table completion inside SQL buffers via blink.cmp/omnifunc.
  --
  -- Connections: drop URLs into ~/.local/share/db_ui/connections.json or set
  -- vim.g.dbs = { rails_dev = "postgresql://..." } in a project-local config.
  {
    "tpope/vim-dadbod",
    cmd = { "DB" },
    dependencies = {
      {
        "kristijanhusak/vim-dadbod-ui",
        cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
        init = function()
          vim.g.db_ui_use_nerd_fonts          = 1
          vim.g.db_ui_show_database_icon      = 1
          vim.g.db_ui_force_echo_notifications = 1
          vim.g.db_ui_win_position            = "left"
          vim.g.db_ui_winwidth                = 40
          vim.g.db_ui_save_location           = vim.fn.stdpath("data") .. "/db_ui"
          vim.g.db_ui_use_nvim_notify         = 1
          -- Rails-aware: auto-load db/structure.sql + config/database.yml is read
          -- by db_ui via :Rails detection (works without vim-rails too).
          vim.g.db_ui_auto_execute_table_helpers = 1
        end,
      },
    },
    keys = {
      { "<leader>Du", "<cmd>DBUIToggle<cr>",         desc = "DB: toggle UI" },
      { "<leader>Df", "<cmd>DBUIFindBuffer<cr>",     desc = "DB: find buffer" },
      { "<leader>Da", "<cmd>DBUIAddConnection<cr>",  desc = "DB: add connection" },
      { "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>",   desc = "DB: rename buffer" },
      { "<leader>Dq", "<cmd>DBUILastQueryInfo<cr>",  desc = "DB: last query info" },
    },
  },

  -- Completion is wired through blink.cmp's native dadbod source (see
  -- sources.per_filetype in lsp.lua); ft trigger ensures the plugin loads
  -- for standalone SQL buffers too. Standalone spec (not a dep of
  -- vim-dadbod) so we can declare the reverse dependency without a cycle:
  -- its FileType autocmd calls db#connect, which needs vim-dadbod loaded.
  {
    "kristijanhusak/vim-dadbod-completion",
    ft = { "sql", "mysql", "plsql" },
    dependencies = { "tpope/vim-dadbod" },
  },

  -- Editable database grids: stage cell edits like a buffer, apply as
  -- transactional SQL (rollback on error). Complements dadbod — reads
  -- g:dbs connections, open_smart() reuses DBUI result windows.
  -- Grid keys: i/<CR> edit cell, n NULL, a apply staged, u undo,
  -- gf follow FK, s sort, f filter, gE export, ? help.
  {
    "joryeugene/dadbod-grip.nvim",
    -- Track main, NOT tags: the repo carries stray v3.x tags that outrank
    -- the real 1.x releases, so version="*" checks out an old code line
    -- missing the mysql `--batch` fix (upstream #11) and a valid lazy.lua.
    version = false,
    -- Command list mirrored from the plugin's lazy.lua packspec; kept
    -- explicit as a guard since upstream has shipped a broken packspec before.
    cmd = {
      "Grip", "GripStart", "GripHome", "GripConnect", "GripSchema",
      "GripTables", "GripQuery", "GripSave", "GripLoad", "GripHistory",
      "GripProfile", "GripExplain", "GripAsk", "GripDiff", "GripCreate",
      "GripDrop", "GripRename", "GripProperties", "GripExport",
      "GripAttach", "GripDetach", "GripOpen",
    },
    keys = {
      { "<leader>Dc", "<cmd>GripConnect<cr>", desc = "DB: grip connect" },
      { "<leader>Dg", "<cmd>Grip<cr>",        desc = "DB: grip grid" },
      { "<leader>Dt", "<cmd>GripTables<cr>",  desc = "DB: grip tables" },
      { "<leader>Ds", "<cmd>GripSchema<cr>",  desc = "DB: grip schema" },
      { "<leader>Dh", "<cmd>GripHistory<cr>", desc = "DB: grip history" },
    },
    opts = {
      completion = false, -- blink.cmp + dadbod-completion already handle SQL
      picker = "snacks",
      -- No natural-language-to-SQL: :GripAsk would ship schema context to
      -- an external LLM API. Keep the DB client offline.
      ai = false,
    },
    config = function(_, opts)
      require("dadbod-grip").setup(opts)

      -- Upstream bug: grip's mysql adapter parses URLs by hand and never
      -- percent-decodes credentials, so the encoded passwords that dadbod /
      -- dadbod-ui require (grip exports its URL to g:db, which they consume)
      -- reach the mysql CLI literally and fail auth. Wrap every adapter
      -- function and decode the userinfo of any mysql:// string argument.
      -- Runtime wrap survives plugin updates; remove once fixed upstream.
      local mysql = require("dadbod-grip.adapters.mysql")
      local function decode_userinfo(url)
        local scheme, auth, rest = url:match("^(%w+://)([^@]+)(@.*)$")
        if not auth then return url end
        auth = auth:gsub("%%(%x%x)", function(h)
          return string.char(tonumber(h, 16))
        end)
        return scheme .. auth .. rest
      end
      for name, fn in pairs(mysql) do
        if type(fn) == "function" then
          mysql[name] = function(...)
            local args = { ... }
            for i = 1, select("#", ...) do
              local a = args[i]
              if type(a) == "string" and a:match("^mysql://") then
                args[i] = decode_userinfo(a)
              end
            end
            return fn(unpack(args))
          end
        end
      end
    end,
  },

  -- REST/HTTP client: edit `.http`/`.rest` files and fire requests from inside
  -- nvim. kulala-core (the request runner) auto-downloads from GitHub releases
  -- on first run; `curl` is the transport, `jq` pretty-prints JSON responses.
  --
  -- We drive everything off explicit `<leader>R*` keymaps below and keep
  -- `global_keymaps = false` so kulala doesn't also register its own default
  -- bindings — this config owns the prefix and the which-key descriptions.
  -- Global entry points (open / send / scratchpad / replay) load the plugin
  -- from any buffer; the rest are gated to `http`/`rest` buffers via `ft` so
  -- they only surface where a request actually exists.
  {
    "mistweaverco/kulala.nvim",
    version = "*", -- stable releases; the core binary is matched to the tag
    ft = { "http", "rest" },
    opts = {
      global_keymaps = false,
      default_env = "default",
      -- Also read VSCode rest-client `.vscode/settings.json` /
      -- `*.code-workspace` env vars when present, merged under http-client.env.json.
      vscode_rest_client_environmentvars = true,
      ui = {
        display_mode = "split",     -- result opens in a split, not a float
        split_direction = "vertical",
        default_view = "body",      -- show response body first; toggle to headers
        winbar = true,              -- pane switcher (body/headers/verbose/stats)
        show_request_summary = true,
      },
    },
    keys = {
      -- Global entry points (work from any buffer; also lazy-load the plugin)
      { "<leader>Ro", function() require("kulala").open() end,       desc = "Kulala: open UI" },
      { "<leader>Rb", function() require("kulala").scratchpad() end, desc = "Kulala: scratchpad" },
      { "<leader>Rs", function() require("kulala").run() end,        mode = { "n", "v" }, desc = "Kulala: send request" },
      { "<leader>Ra", function() require("kulala").run_all() end,    mode = { "n", "v" }, desc = "Kulala: send all requests" },
      { "<leader>Rr", function() require("kulala").replay() end,     desc = "Kulala: replay last request" },

      -- http/rest buffer actions
      { "<leader>Rt", function() require("kulala").toggle_view() end,            ft = { "http", "rest" }, desc = "Kulala: toggle headers/body" },
      { "<leader>Ri", function() require("kulala").inspect() end,                ft = { "http", "rest" }, desc = "Kulala: inspect request" },
      { "<leader>RS", function() require("kulala").show_stats() end,             ft = { "http", "rest" }, desc = "Kulala: show stats" },
      { "<leader>Rf", function() require("kulala").search() end,                 ft = { "http", "rest" }, desc = "Kulala: find request" },
      { "<leader>Rn", function() require("kulala").jump_next() end,              ft = { "http", "rest" }, desc = "Kulala: next request" },
      { "<leader>Rp", function() require("kulala").jump_prev() end,              ft = { "http", "rest" }, desc = "Kulala: prev request" },
      { "<leader>Re", function() require("kulala").set_selected_env() end,       ft = { "http", "rest" }, desc = "Kulala: select environment" },
      { "<leader>Rc", function() require("kulala").copy() end,                   ft = { "http", "rest" }, desc = "Kulala: copy as cURL" },
      { "<leader>RC", function() require("kulala").from_curl() end,              ft = { "http", "rest" }, desc = "Kulala: paste from cURL" },
      { "<leader>Rj", function() require("kulala").open_cookies_jar() end,       ft = { "http", "rest" }, desc = "Kulala: open cookies jar" },
      { "<leader>Rg", function() require("kulala").download_graphql_schema() end, ft = { "http", "rest" }, desc = "Kulala: download GraphQL schema" },
      { "<leader>Rq", function() require("kulala").close() end,                  ft = { "http", "rest" }, desc = "Kulala: close window" },
      { "<leader>Rx", function() require("kulala").scripts_clear_global() end,   ft = { "http", "rest" }, desc = "Kulala: clear global vars" },
      { "<leader>RX", function() require("kulala").clear_cached_files() end,     ft = { "http", "rest" }, desc = "Kulala: clear cached files" },
    },
  },

}
