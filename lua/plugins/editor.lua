return {
  -- Auto-detect indentation
  { "tpope/vim-sleuth", event = "BufReadPre" },

  -- Folding with treesitter + peek preview
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    opts = {
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
    },
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,               desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end,              desc = "Close all folds" },
      { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Peek fold" },
    },
  },

  -- Undo tree visualization
  {
    "mbbill/undotree",
    keys = {
      { "<leader>cu", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
    },
  },

  -- Split/join code blocks (single-line <-> multi-line)
  {
    "Wansmer/treesj",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>cj", function() require("treesj").toggle() end, desc = "Split/join block" },
    },
    opts = {
      use_default_keymaps = false,
      max_join_length = 150,
    },
  },

  -- Refactoring (extract function/variable, inline)
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>Re", function() require("refactoring").select_refactor() end, mode = "v",          desc = "Refactor (select)" },
      { "<leader>Rf", function() require("refactoring").extract_func() end,    mode = "v",          desc = "Extract function" },
      { "<leader>Rv", function() require("refactoring").extract_var() end,     mode = "v",          desc = "Extract variable" },
      { "<leader>Ri", function() require("refactoring").inline_var() end,      mode = { "n", "v" }, desc = "Inline variable" },
    },
    opts = {},
  },

  -- Autopairs (ultimate-autopair — smarter multiline / JSX handling)
  {
    "altermo/ultimate-autopair.nvim",
    event = { "InsertEnter", "CmdlineEnter" },
    branch = "v0.6",
    opts = {},
  },

  -- Surround (gs prefix)
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  -- Search and replace
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      { "<leader>sr", function() require("grug-far").open() end, desc = "Search / replace (grug-far)" },
      { "<leader>sR", function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end, desc = "Grug-far: word under cursor" },
      { "<leader>sR", function() require("grug-far").with_visual_selection() end, mode = "x", desc = "Grug-far: visual selection" },
    },
    config = true,
  },

  -- Jump navigation
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        char = { enabled = false }, -- don't hijack f/F/t/T
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,       desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- Inline markdown rendering (headings, code blocks, tables, LaTeX, mermaid, links)
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "codecompanion", "Avante" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    keys = {
      { "<leader>uM", "<cmd>Markview Toggle<cr>", desc = "Toggle markdown render", ft = { "markdown", "codecompanion", "Avante" } },
    },
    opts = {
      preview = {
        filetypes = { "markdown", "codecompanion", "Avante" },
        ignore_buftypes = {},
      },
    },
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo comments" },
    },
  },

  -- Better buffer delete (preserves window layout)
  {
    "echasnovski/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end,  desc = "Delete buffer (force)" },
    },
  },

  -- Enhanced text objects (around/inside)
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = {},
  },

  -- Yank history ring
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      ring = { history_length = 100 },
    },
    keys = {
      { "y",     "<Plug>(YankyYank)",          mode = { "n", "x" },     desc = "Yank" },
      { "p",     "<Plug>(YankyPutAfter)",      mode = { "n", "x" },     desc = "Put after" },
      { "P",     "<Plug>(YankyPutBefore)",     mode = { "n", "x" },     desc = "Put before" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "Prev yank entry" },
      { "<C-n>", "<Plug>(YankyNextEntry)",     desc = "Next yank entry" },
    },
  },

  -- Multi-cursor editing (VSCode-style match selection)
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
      { "<leader>mn", function() require("multicursor-nvim").matchAddCursor(1) end, mode = { "n", "x" }, desc = "Add cursor at next match" },
      { "<leader>mN", function() require("multicursor-nvim").matchAddCursor(-1) end, mode = { "n", "x" }, desc = "Add cursor at prev match" },
      { "<leader>ms", function() require("multicursor-nvim").matchSkipCursor(1) end, mode = { "n", "x" }, desc = "Skip match (next)" },
      { "<leader>mS", function() require("multicursor-nvim").matchSkipCursor(-1) end, mode = { "n", "x" }, desc = "Skip match (prev)" },
      { "<leader>ma", function() require("multicursor-nvim").matchAllAddCursors() end, mode = { "n", "x" }, desc = "Add cursor at all matches" },
      { "<leader>mx", function() require("multicursor-nvim").deleteCursor() end, mode = { "n", "x" }, desc = "Delete cursor under main" },
      { "<leader>mj", function() require("multicursor-nvim").lineAddCursor(1) end, mode = { "n", "x" }, desc = "Add cursor down" },
      { "<leader>mk", function() require("multicursor-nvim").lineAddCursor(-1) end, mode = { "n", "x" }, desc = "Add cursor up" },
      { "<leader>mJ", function() require("multicursor-nvim").lineSkipCursor(1) end, mode = { "n", "x" }, desc = "Skip line down" },
      { "<leader>mK", function() require("multicursor-nvim").lineSkipCursor(-1) end, mode = { "n", "x" }, desc = "Skip line up" },
      { "<leader>mr", function() require("multicursor-nvim").restoreCursors() end, mode = "n", desc = "Restore cursors" },
      { "<leader>ml", function() require("multicursor-nvim").alignCursors() end, mode = { "n", "x" }, desc = "Align cursors" },
      { "<leader>mp", function() require("multicursor-nvim").splitCursors() end, mode = "x", desc = "Split selection by regex" },
      { "<leader>mt", function() require("multicursor-nvim").transposeCursors(1) end, mode = "x", desc = "Transpose cursors" },
      { "<C-q>", function() require("multicursor-nvim").toggleCursor() end, mode = { "n", "x" }, desc = "Toggle cursor" },
      { "<C-LeftMouse>", function() require("multicursor-nvim").handleMouse() end, mode = "n", desc = "Toggle cursor at click" },
    },
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      -- Cursor layer: bindings active only while extra cursors exist
      mc.addKeymapLayer(function(layerSet)
        layerSet({ "n", "x" }, "<left>", mc.prevCursor)
        layerSet({ "n", "x" }, "<right>", mc.nextCursor)
        layerSet({ "n", "x" }, "<tab>", mc.nextCursor)
        layerSet({ "n", "x" }, "<s-tab>", mc.prevCursor)
        layerSet("n", "<esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end,
  },

  -- HTTP client (REST API testing via Hurl)
  {
    "jellydn/hurl.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    ft = "hurl",
    cmd = { "HurlRunner", "HurlRunnerAt", "HurlRunnerToEntry", "HurlToggleMode", "HurlVerbose" },
    keys = {
      { "<leader>Ha", "<cmd>HurlRunner<CR>", desc = "Run all requests" },
      { "<leader>Hs", "<cmd>HurlRunnerAt<CR>", desc = "Run request at cursor" },
      { "<leader>He", "<cmd>HurlRunnerToEntry<CR>", desc = "Run up to entry" },
      { "<leader>Hm", "<cmd>HurlToggleMode<CR>", desc = "Toggle result mode" },
      { "<leader>Hv", "<cmd>HurlVerbose<CR>", desc = "Run in verbose mode" },
      { "<leader>H", "<cmd>HurlRunner<CR>", desc = "Run selection", mode = "v" },
    },
    opts = {
      debug = false,
      show_notification = true,
      mode = "split",
      formatters = {
        json = { "jq" },
        html = { "prettier", "--parser", "html" },
        xml = { "tidy", "-xml", "-i", "-q" },
      },
    },
  },

  -- Better quickfix window with preview + fzf filter
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      preview = { winblend = 0 },
    },
  },

  -- Search match count/index overlay
  {
    "kevinhwang91/nvim-hlslens",
    event = "VeryLazy",
    config = true,
  },

  -- Enhanced increment/decrement (booleans, dates, semver, etc.)
  {
    "monaqa/dial.nvim",
    keys = {
      { "<C-a>", function() require("dial.map").manipulate("increment", "normal") end, desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end, desc = "Decrement" },
      { "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, mode = "v",        desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, mode = "v",        desc = "Decrement" },
    },
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({
        default = {
          augend.integer.alias.decimal_int,
          augend.integer.alias.hex,
          augend.constant.alias.bool,
          augend.date.alias["%Y-%m-%d"],
          augend.date.alias["%Y/%m/%d"],
          augend.semver.alias.semver,
          augend.constant.new({ elements = { "true", "false" } }),
          augend.constant.new({ elements = { "True", "False" } }),
          augend.constant.new({ elements = { "yes", "no" } }),
          augend.constant.new({ elements = { "on", "off" } }),
          augend.constant.new({ elements = { "let", "const" } }),
          augend.constant.new({ elements = { "&&", "||" }, word = false }),
        },
      })
    end,
  },

  -- Better commentstring for embedded languages (JSX, Vue, etc.)
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Enhanced % matching for language constructs (if/else/end, etc.)
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  -- Create/edit snippets from Neovim
  {
    "chrisgrieser/nvim-scissors",
    dependencies = { "rafamadriz/friendly-snippets" },
    keys = {
      { "<leader>Se", function() require("scissors").editSnippet() end,   desc = "Edit snippet" },
      { "<leader>Sa", function() require("scissors").addNewSnippet() end, mode = { "n", "x" },  desc = "Add snippet" },
    },
    opts = {
      snippetDir = vim.fn.stdpath("config") .. "/snippets",
    },
  },

  -- Show marks in sign column
  {
    "chentoast/marks.nvim",
    event = "BufReadPost",
    opts = {
      default_mappings = true,
    },
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f",  group = "find" },
        { "<leader>s",  group = "search" },
        { "<leader>g",  group = "git" },
        { "<leader>gh", group = "hunks" },
        { "<leader>b",  group = "buffer" },
        { "<leader>q",  group = "quit/session" },
        { "<leader>t",  group = "todo" },
        { "<leader>u",  group = "ui" },
        { "<leader>x",  group = "diagnostics" },
        { "<leader>c",  group = "code" },
        { "<leader>cs", group = "swap" },
        { "<leader>d",  group = "debug" },
        { "<leader>T",  group = "test" },
        { "<leader>h",  group = "harpoon" },
        { "<leader>i",  group = "iron repl" },
        { "<leader>m",  group = "multicursor" },
        { "<leader>n",  group = "ast nav" },
        { "<leader>o",  group = "overseer" },
        { "<leader>r",  group = "rails" },
        { "<leader>R",  group = "refactor" },
        { "<leader>S",  group = "snippets" },
        { "<leader>H",  group = "hurl" },
        { "<leader>a",  group = "ai/claude" },
        { "<leader>D",  group = "database" },
        { "<leader>w",  group = "window" },
        { "g",          group = "goto" },
        { "gs",         group = "surround" },
      },
    },
  },
  {
    "bngarren/checkmate.nvim",
    ft = "markdown", -- activates on markdown files matching `files` patterns below
    opts = {
      -- files = { "*.md" }, -- any .md file (instead of defaults)
      keys = {
        ["<leader>tt"] = { rhs = "<cmd>Checkmate toggle<CR>",          desc = "Toggle todo item",        modes = { "n", "v" } },
        ["<leader>tc"] = { rhs = "<cmd>Checkmate check<CR>",           desc = "Check todo item",         modes = { "n", "v" } },
        ["<leader>tu"] = { rhs = "<cmd>Checkmate uncheck<CR>",         desc = "Uncheck todo item",       modes = { "n", "v" } },
        ["<leader>t="] = { rhs = "<cmd>Checkmate cycle_next<CR>",      desc = "Cycle next state",        modes = { "n", "v" } },
        ["<leader>t-"] = { rhs = "<cmd>Checkmate cycle_previous<CR>",  desc = "Cycle previous state",    modes = { "n", "v" } },
        ["<leader>tn"] = { rhs = "<cmd>Checkmate create<CR>",          desc = "New todo item",           modes = { "n", "v" } },
        ["<leader>tx"] = { rhs = "<cmd>Checkmate remove<CR>",          desc = "Remove todo marker",      modes = { "n", "v" } },
        ["<leader>tR"] = { rhs = "<cmd>Checkmate remove_all_metadata<CR>", desc = "Remove all metadata", modes = { "n", "v" } },
        ["<leader>ta"] = { rhs = "<cmd>Checkmate archive<CR>",         desc = "Archive completed",       modes = { "n" } },
        ["<leader>tf"] = { rhs = "<cmd>Checkmate select_todo<CR>",     desc = "Find todo (picker)",      modes = { "n" } },
        ["<leader>tv"] = { rhs = "<cmd>Checkmate metadata select_value<CR>", desc = "Set metadata value", modes = { "n" } },
        ["<leader>t]"] = { rhs = "<cmd>Checkmate metadata jump_next<CR>",     desc = "Next metadata tag",  modes = { "n" } },
        ["<leader>t["] = { rhs = "<cmd>Checkmate metadata jump_previous<CR>", desc = "Prev metadata tag",  modes = { "n" } },
      },
      -- Metadata `key` fields override the defaults' <leader>T* mappings onto <leader>t*.
      -- Providing an entry here fully replaces that metadata's default, so copy any fields you want to keep.
      metadata = {
        priority = {
          style = function(context)
            local value = context.value:lower()
            if value == "high" then
              return { fg = "#ff5555", bold = true }
            elseif value == "medium" then
              return { fg = "#ffb86c" }
            elseif value == "low" then
              return { fg = "#8be9fd" }
            else
              return { fg = "#8be9fd" }
            end
          end,
          get_value = function() return "medium" end,
          choices = function() return { "low", "medium", "high" } end,
          key = "<leader>tp",
          sort_order = 10,
          jump_to_on_insert = "value",
          select_on_insert = true,
        },
        started = {
          aliases = { "init" },
          style = { fg = "#9fd6d5" },
          get_value = function() return tostring(os.date("%m/%d/%y %H:%M")) end,
          key = "<leader>ts",
          sort_order = 20,
        },
        done = {
          aliases = { "completed", "finished" },
          style = { fg = "#96de7a" },
          get_value = function() return tostring(os.date("%m/%d/%y %H:%M")) end,
          key = "<leader>td",
          on_add = function(todo)
            require("checkmate").set_todo_state(todo, "checked")
          end,
          on_remove = function(todo)
            require("checkmate").set_todo_state(todo, "unchecked")
          end,
          sort_order = 30,
        },
      },
    },
  },

  -- Makes `.` repeat plugin mappings (mini.surround, yanky, etc.)
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- Case-preserving :Subvert/:S and `crs`/`crc`/`crm`/`cru`/`cr-`/`cr.` case coercions
  { "tpope/vim-abolish", event = "VeryLazy" },

  -- Highlight other uses of the symbol under cursor (LSP/Treesitter/regex)
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 120,
        filetypes_denylist = { "oil", "trouble", "lazy", "mason", "help", "noice", "checkhealth", "snacks_picker_list" },
        min_count_to_highlight = 2,
      })
      vim.keymap.set("n", "]]", function() require("illuminate").goto_next_reference(false) end, { desc = "Next reference" })
      vim.keymap.set("n", "[[", function() require("illuminate").goto_prev_reference(false) end, { desc = "Prev reference" })
    end,
  },

}
