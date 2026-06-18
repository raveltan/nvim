return {
  -- Auto-detect indentation
  { "tpope/vim-sleuth", event = "BufReadPre" },

  -- Hard/soft wrap mode manager
  {
    "andrewferrier/wrapping.nvim",
    event = "BufReadPre",
    opts = {
      auto_set_mode_filetype_allowlist = {},
      auto_set_mode_filetype_denylist = {},
      auto_set_mode_heuristically = false,
      create_commands = true,
      create_keymappings = false,
      notify_on_switch = false,
      set_nvim_opt_defaults = true,
      softener = { default = true },
    },
    config = function(_, opts)
      require("wrapping").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("force_hybridwrap", { clear = true }),
        callback = function(ev)
          -- Special buffers (prompt/dap-repl, terminal, quickfix, help, nofile)
          -- inherit Neovim's default fo `tcqj`. The `t` auto-reflows at textwidth
          -- and jumps the cursor on each keystroke (e.g. typing in the dap REPL).
          -- buftype is set before FileType fires (nvim-dap repl.lua), so this
          -- branch reliably catches the prompt buffer — strip `t` + textwidth.
          if vim.bo[ev.buf].buftype ~= "" then
            vim.opt_local.formatoptions:remove("t")
            vim.opt_local.textwidth = 0
            return
          end
          vim.opt_local.wrap = true
          -- Commit messages: keep the ftplugin's textwidth=72 / fo+=tl so they
          -- hard-wrap at the conventional width. Still re-assert soft wrap above,
          -- because wrapping.nvim's set_nvim_opt_defaults turns global 'wrap' off.
          if ev.match == "gitcommit" or ev.match == "NeogitCommitMessage" then
            return
          end
          vim.opt_local.textwidth = 150
          vim.opt_local.formatoptions:append("t")
          vim.opt_local.formatoptions:append("l")
        end,
      })
    end,
  },

  -- Undo tree visualization. Vim undo is a TREE — after undo+new edit the old
  -- "redo" path becomes a branch <C-r> can't reach; undotree (and g-/g+)
  -- navigate those branches. edgy owns placement (left panel + diff below).
  {
    "mbbill/undotree",
    keys = {
      { "<leader>U", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
    },
    init = function()
      vim.g.undotree_SetFocusWhenToggle = 1 -- focus tree on open
      vim.g.undotree_ShortIndicators = 1    -- compact timestamps
    end,
  },

  -- Autopairs (ultimate-autopair — smarter multiline / JSX handling).
  -- cr.enable=false: its <CR> handler remaps imap <CR> with noremap=true and
  -- displaces vim-endwise's <Plug>DiscretionaryEnd map. Disabling restores the
  -- endwise chain so blink.cmp's "fallback" finds endwise and inserts `end`
  -- for def/do/if/class/module on Enter in Ruby/Lua/Vim buffers.
  -- Trade-off: typing <CR> inside `{|}` no longer expands to `{\n|\n}` —
  -- use `o` or a snippet for that case.
  {
    "altermo/ultimate-autopair.nvim",
    event = { "InsertEnter", "CmdlineEnter" },
    branch = "v0.6",
    opts = {
      cr = { enable = false },
    },
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
        char = { enabled = true },
      },
    },
    keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- Inline markdown rendering (headings, code blocks, tables, LaTeX, mermaid, links)
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    keys = {
      { "<leader>uM", "<cmd>Markview Toggle<cr>", desc = "Toggle markdown render", ft = { "markdown", "Avante" } },
    },
    opts = {
      preview = {
        filetypes = { "markdown", "Avante" },
        -- Ignore `nofile` buffers: LSP hover floats (vim.lsp.buf.hover) are
        -- nofile + filetype=markdown, so an empty list let markview attach and
        -- draw its code-block box on them — collapsing intelephense's `<?php` hover
        -- to a ~3-char-wide popup. Real .md files are normal buftype, still render.
        ignore_buftypes = { "nofile" },
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
    opts = {
      custom_textobjects = {
        -- Override the default `t` tag text object so `dit`/`cit`/`dat`/`cat` match
        -- hyphenated custom elements (`<fl-button>`, `<app-foo-bar>`). Upstream uses
        -- `(%w-)` for the tag name, which stops at the first hyphen; widen the name
        -- class and its frontier to include `-`. Second pattern (inner/around split)
        -- is mini.ai's default, unchanged.
        t = { "<([%w%-]-)%f[^<%w%-][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
      },
    },
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
      -- Default 150ms poll ran getmarklist()+getmarklist("%") on the main loop
      -- ~7x/sec forever; manually-set mark signs tolerate 1s fine.
      refresh_interval = 1000,
    },
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = function()
      local spec = {
        { "<leader>b",  group = "buffer" },
        { "<leader>c",  group = "code" },
        { "<leader>cs", group = "swap" },
        { "<leader>d",  group = "debug" },
        { "<leader>D",  group = "database" },
        { "<leader>f",  group = "find/files" },
        { "<leader>g",  group = "git" },
        { "<leader>h",  group = "harpoon" },
        { "<leader>k",  group = "docs (devdocs/nvimdocs)" },
        { "<leader>n",  group = "obsidian" },
        { "<leader>o",  group = "overseer/other" },
        { "<leader>s",  group = "search" },
        { "<leader>S",  group = "snippets" },
        { "<leader>t",  group = "todo/test" },
        { "<leader>u",  group = "ui" },
        { "<leader>ud", group = "duck" },
        { "<leader>x",  group = "diagnostics/quickfix" },
        { "<leader>X",  group = "xdebug profile" },
        { "g",          group = "goto" },
        { "gs",         group = "surround" },
      }
      -- Redash keys are registered only under the GAF profile — keep the
      -- which-key group out of <leader>r when redash.nvim isn't loaded.
      if vim.g.gaf then
        table.insert(spec, { "<leader>r", group = "redash" })
      end
      return { spec = spec }
    end,
  },
  -- Obsidian vault integration (community-maintained fork; epwalsh's repo is abandoned).
  -- ui.enable = false: checkmate.nvim owns checkbox rendering, prevents extmark collision.
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    cmd = { "Obsidian" },
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = "personal", path = "~/Documents/Obsidian" },
      },
      notes_subdir = "inbox",
      new_notes_location = "notes_subdir",
      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        default_tags = { "daily" },
        template = "daily.md",
      },
      templates = {
        folder = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
        substitutions = {
          yesterday = function()
            return os.date("%Y-%m-%d", os.time() - 86400)
          end,
          tomorrow = function()
            return os.date("%Y-%m-%d", os.time() + 86400)
          end,
        },
      },
      ui = { enable = false },
      completion = {
        blink = true,
        min_chars = 2,
      },
      picker = { name = "snacks.pick" },
      link = {
        style = function(opts)
          return string.format("[[%s]]", tostring(opts.label or ""))
        end,
      },
      frontmatter = { enabled = true },
      note_id_func = function(title)
        if title ~= nil then
          local slug = title:lower():gsub("[^%w%s%-_]", ""):gsub("%s+", "-"):gsub("%-+", "-")
          return slug:gsub("^%-", ""):gsub("%-$", "")
        end
        return os.date("%Y%m%d%H%M%S")
      end,
    },
    keys = {
      -- Navigation / search
      { "<leader>nf", "<cmd>Obsidian quick_switch<cr>", desc = "Find note (quick switch)" },
      { "<leader>ns", "<cmd>Obsidian search<cr>",       desc = "Search vault content" },
      { "<leader>ng", "<cmd>Obsidian tags<cr>",         desc = "Tags picker" },
      { "<leader>nb", "<cmd>Obsidian backlinks<cr>",    desc = "Backlinks" },
      { "<leader>nl", "<cmd>Obsidian links<cr>",        desc = "Links in note" },
      { "<leader>nF", "<cmd>Obsidian follow_link<cr>",  desc = "Follow link" },
      { "<leader>no", "<cmd>Obsidian open<cr>",         desc = "Open in Obsidian app" },
      { "<leader>nW", "<cmd>Obsidian workspace<cr>",    desc = "Switch workspace" },

      -- Daily / review
      { "<leader>nd", "<cmd>Obsidian today<cr>",       desc = "Today's daily" },
      { "<leader>ny", "<cmd>Obsidian yesterday<cr>",   desc = "Yesterday's daily" },
      { "<leader>nT", "<cmd>Obsidian tomorrow<cr>",    desc = "Tomorrow's daily" },
      { "<leader>nR", function() require("util.obsidian").weekly_review() end, desc = "Weekly review" },

      -- Capture (fast inbox dump)
      { "<leader>nc", function() require("util.obsidian").capture("inbox") end, desc = "Capture to inbox" },
      { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "New note (raw, inbox)" },

      -- From-template creators
      { "<leader>np", function() require("util.obsidian").new_from_template({ folder = "projects", template = "project", prompt = "Project name: " }) end, desc = "New project" },
      { "<leader>nm", function() require("util.obsidian").new_from_template({ folder = "meetings", template = "meeting", prompt = "Meeting title: ", date_prefix = true }) end, desc = "New meeting" },
      { "<leader>nu", function() require("util.obsidian").new_from_template({ folder = "notes/bugs", template = "bug", prompt = "Bug symptom: " }) end, desc = "New bug" },
      { "<leader>nD", function() require("util.obsidian").new_from_template({ folder = "notes/decisions", template = "decision", prompt = "Decision title: ", date_prefix = true }) end, desc = "New decision (ADR)" },
      { "<leader>nk", function() require("util.obsidian").new_from_template({ folder = "notes/concepts", template = "concept", prompt = "Concept name: " }) end, desc = "New concept (knowledge)" },
      { "<leader>nP", function() require("util.obsidian").new_from_template({ folder = "people", template = "person", prompt = "Person name: " }) end, desc = "New person" },
      { "<leader>nS", function() require("util.obsidian").new_from_template({ folder = "snippets", template = "snippet", prompt = "Snippet title: " }) end, desc = "New snippet" },
      { "<leader>nB", function() require("util.obsidian").new_from_template({ folder = "notes/books", template = "book", prompt = "Book title: " }) end, desc = "New book" },

      -- Editing
      { "<leader>ni", "<cmd>Obsidian template<cr>",     desc = "Insert template at cursor" },
      { "<leader>nr", "<cmd>Obsidian rename<cr>",       desc = "Rename note (refactor links)" },
      { "<leader>nI", "<cmd>Obsidian paste_img<cr>",    desc = "Paste image" },
      { "<leader>nL", "<cmd>Obsidian link<cr>", mode = "v", desc = "Link selection" },
      { "<leader>nX", "<cmd>Obsidian extract_note<cr>", mode = "v", desc = "Extract selection → note" },
      { "<leader>nt", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
      { "<leader>nC", "<cmd>Obsidian toc<cr>",          desc = "Table of contents" },
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

  -- Case conversion. Used only for its pure string functions
  -- (require("textcase.conversions.stringcase")), driven by the <leader>cv
  -- picker in lua/config/keymaps.lua. Default `ga`/`gA` keymaps off.
  {
    "johmsalas/text-case.nvim",
    lazy = true,
    config = function()
      require("textcase").setup({ default_keymappings_enabled = false })
    end,
  },

  -- Better quickfix: editable, prettier
  {
    "stevearc/quicker.nvim",
    event = "FileType qf",
    opts = {
      keys = {
        { ">", function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end, desc = "Expand qf context" },
        { "<", function() require("quicker").collapse() end, desc = "Collapse qf context" },
      },
    },
    keys = {
      { "<leader>xq", function() require("quicker").toggle() end, desc = "Toggle quickfix" },
    },
  },

  -- Flash region on undo/redo
  {
    "tzachar/highlight-undo.nvim",
    keys = { "u", "<C-r>" },
    opts = {},
  },

  -- Winbar breadcrumbs (LSP/TS symbol path, keyboard-navigable)
  {
    "Bekaboo/dropbar.nvim",
    dependencies = { "nvim-telescope/telescope-fzf-native.nvim" },
    event = "BufReadPost",
    opts = {
      bar = {
        enable = function(buf, win)
          if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then return false end
          if vim.fn.win_gettype(win) ~= "" then return false end
          if vim.wo[win].diff then return false end
          local ft = vim.bo[buf].filetype
          local skip = { oil = true, qf = true, help = true, lazy = true, mason = true, trouble = true, ["snacks_picker_list"] = true, ["dap-repl"] = true, ["dapui_scopes"] = true, ["dapui_breakpoints"] = true, ["dapui_stacks"] = true, ["dapui_watches"] = true, ["dapui_console"] = true, ["neotest-summary"] = true, ["neotest-output"] = true, ["neotest-output-panel"] = true, gitcommit = true, NeogitCommitMessage = true }
          if skip[ft] then return false end
          return vim.bo[buf].buftype == ""
        end,
      },
    },
    keys = {
      { "<leader>;", function() require("dropbar.api").pick() end, desc = "Dropbar pick (breadcrumb nav)" },
      { "[;", function() require("dropbar.api").goto_context_start() end, desc = "Goto context start" },
      { "];", function() require("dropbar.api").select_next_context() end, desc = "Select next context" },
    },
  },

  -- Cycle LSP references inline with ]r / [r (no picker)
  {
    "mawkler/refjump.nvim",
    keys = { "]r", "[r" },
    opts = {
      keymaps = { enable = true },
      highlights = { enable = true },
    },
  },

}
