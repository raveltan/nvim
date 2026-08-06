return {
  -- Colorscheme
  {
    "bluz71/vim-moonfly-colors",
    name = "moonfly",
    priority = 1000,
    lazy = false,
    config = function()
      -- No setup() — moonfly is a VimScript colorscheme configured via g:moonfly*
      -- globals read at load time, so set them BEFORE the colorscheme command.
      -- Transparency MUST be boolean true (not 1), else statusline/tabline stay
      -- opaque (some branches test `== true`). moonfly sets termguicolors +
      -- background=dark itself.
      vim.g.moonflyTransparent = true
      -- 1 (default) draws BLOCK separators: VertSplit gets bg=fg=grey16, i.e. a
      -- solid bar that survives transparency. 2 is the line style moonfly itself
      -- renders as bg=NONE, which is what the transparent setup wants.
      vim.g.moonflyWinSeparator = 2

      -- The float surface every override below blends against (moonfly grey13),
      -- and grey15 for chrome that sits flush against buffer text.
      local float_bg = "#212121"
      local context_bg = "#262626"

      local function overrides()
        -- Belt-and-suspenders: force-clear backgrounds on groups the theme's own
        -- transparency may leave opaque (statusline, separators).
        -- NormalFloat is deliberately NOT here: moonfly gives floats a grey13
        -- (#212121) surface even in transparent mode (see its g:moonflyNormalFloat
        -- branch), and clearing it made hover docs, the blink menu and pickers
        -- render on top of live buffer text. Transparent editor, solid floats —
        -- which is also why the float chrome below blends INTO grey13 rather than
        -- being cleared.
        local transparent_groups = {
          "Normal",
          "NormalNC",
          "SignColumn",
          "StatusLine",
          "StatusLineNC",
          "WinSeparator",
        }
        -- link=false is load-bearing: nvim_get_hl on a linked group returns
        -- { link = "Target" }, and nvim_set_hl ignores every other attribute when a
        -- link is present, so bg="NONE" was silently dropped. Resolving the link
        -- first returns the target's real attributes and breaks the link on write.
        for _, group in ipairs(transparent_groups) do
          local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
          hl.bg = "NONE"
          vim.api.nvim_set_hl(0, group, hl)
        end

        -- WinSeparator's line char inherits grey16 (#292929), which is 41/255 from
        -- Ghostty's black — the split boundary vanished. grey27 is what moonfly
        -- already uses for FloatBorder, so borders and splits now read alike.
        vim.api.nvim_set_hl(0, "WinSeparator", { bg = "NONE", fg = "#444444" })

        -- Contrast fixes measured against the actual terminal background (Ghostty is
        -- #000000): moonfly ships ColorColumn and TreesitterContext at #121212, which
        -- is 18/255 away from black — effectively invisible once Normal is bg=NONE.
        -- ColorColumn must also clear CursorLine (#1c1c1c) or the rule disappears on
        -- the cursor's own line, which is the line you are usually measuring.
        vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#262626" })
        -- The sticky context reads as a pinned panel on surface alone — one step
        -- above the float surface, since it sits directly against buffer text with
        -- no border or gap to separate it (nvim-treesitter-context renders into a
        -- plain float and has no padding option).
        vim.api.nvim_set_hl(0, "TreesitterContext", { bg = context_bg })
        vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", { bg = context_bg, fg = "#6d6d6d" })
        -- render.lua:528 underlines the last context row via
        -- TreesitterContextBottom unconditionally — dropping `separator` did not
        -- remove it. moonfly asks for sp=#2e2e2e, but the underline color is not
        -- being honoured, so it drew in Normal's #c6c6c6: a near-white rule welded
        -- to the code below. Surface only, no underline.
        vim.api.nvim_set_hl(0, "TreesitterContextBottom", { bg = context_bg })
        vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", { bg = context_bg, fg = "#6d6d6d" })
        -- Inlay hints inherited bg #1c1c1c, i.e. a grey box floating in transparent
        -- code. Italic + dim fg on no background is the readable form.
        vim.api.nvim_set_hl(0, "LspInlayHint", { bg = "NONE", fg = "#6d6d6d", italic = true })

        -- Flush float chrome. Borders keep their cell (the padding is what makes a
        -- float readable over code) but are painted in the surface color, so no
        -- frame is drawn. Three groups, because moonfly splits them:
        --   FloatBorder            grey13/grey27 — LSP hover, blink, fff, which-key
        --   FloatBorderTransparent NONE/grey18   — snacks, telescope, fzf, notify,
        --                                          dap-ui, mini; a see-through ring
        --                                          around an opaque grey13 body,
        --                                          which is the mismatch that read
        --                                          as a "weird" double edge
        --   FloatTitle             grey23/white  — a lighter chip welded onto the
        --                                          top border ("Files", "+goto")
        vim.api.nvim_set_hl(0, "FloatBorder", { bg = float_bg, fg = float_bg })
        vim.api.nvim_set_hl(0, "FloatBorderTransparent", { bg = float_bg, fg = float_bg })
        vim.api.nvim_set_hl(0, "FloatTitle", { bg = float_bg, fg = "#9e9e9e" })
      end

      vim.cmd.colorscheme("moonfly")
      overrides()
      -- Anything that re-runs the colorscheme (a :colorscheme moonfly, a plugin
      -- reload) restores moonfly's own definitions and drops all of the above.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("moonfly_overrides", { clear = true }),
        pattern = "moonfly",
        callback = overrides,
      })
    end,
  },

  -- Icons
  {
    "echasnovski/mini.icons",
    lazy = true,
    config = true,
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "echasnovski/mini.icons",
      -- showtabline=0 + harpoon meant the marks were invisible everywhere; this
      -- renders them in the statusline instead of reintroducing a tabline.
      { "letieu/harpoon-lualine", dependencies = { "ThePrimeagen/harpoon" } },
    },
    opts = function()
      local macro = {
        function()
          local r = vim.fn.reg_recording()
          return r ~= "" and ("REC @" .. r) or ""
        end,
        cond = function() return vim.fn.reg_recording() ~= "" end,
        color = { fg = "#ff5555", gui = "bold" },
      }

      local lsp = {
        function()
          local cs = vim.lsp.get_clients({ bufnr = 0 })
          if #cs == 0 then return "" end
          local names = {}
          for _, c in ipairs(cs) do table.insert(names, c.name) end
          return " " .. table.concat(names, ",")
        end,
      }

      -- Pending plugin updates, hidden when there are none.
      local lazy_updates = {
        function() return "󰚰 " .. require("lazy.status").updates() end,
        cond = function() return require("lazy.status").has_updates() end,
        color = { fg = "#e3c78a" }, -- moonfly yellow
      }

      -- Show encoding/fileformat only when non-default
      local encoding = {
        "encoding",
        cond = function() return (vim.bo.fileencoding or "") ~= "" and vim.bo.fileencoding ~= "utf-8" end,
      }
      local fileformat = {
        "fileformat",
        cond = function() return vim.bo.fileformat ~= "unix" end,
      }

      -- Refresh on macro start/stop. ModeChanged dropped: lualine already
      -- redraws on mode change internally, the extra refresh just doubled work
      -- on every n↔i↔v↔c transition.
      vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
        callback = function() require("lualine").refresh() end,
      })

      return {
        options = {
          theme = "moonfly",
          globalstatus = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "snacks_dashboard", "starter" },
          },
        },
        sections = {
          lualine_a = { { "mode", icon = "" } },
          lualine_b = {
            { "branch", icon = "" },
            { "diff", symbols = { added = " ", modified = " ", removed = " " } },
            { "diagnostics", symbols = { error = " ", warn = " ", info = " ", hint = " " } },
          },
          lualine_c = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            -- path=1 (relative dir + name): with globalstatus there is exactly one
            -- statusline, so a bare filename left "which of these three
            -- component.ts is focused?" unanswerable.
            { "filename", path = 1, symbols = { modified = "  ", readonly = " ", unnamed = " " } },
            macro,
            -- Harpoon marks: 1 2 [3] 4 — brackets mark the current file. Renders
            -- nothing when the list is empty (no_harpoon = "").
            {
              "harpoon2",
              indicators = { "1", "2", "3", "4", "5" },
              active_indicators = { "[1]", "[2]", "[3]", "[4]", "[5]" },
              _separator = " ",
              no_harpoon = "",
              color = { fg = "#74b2ff" }, -- moonfly sky
            },
          },
          lualine_x = { lazy_updates, lsp, encoding, fileformat },
          lualine_y = { "progress" },
          lualine_z = { { "location", icon = "" } },
        },
        extensions = { "lazy", "mason", "neo-tree", "trouble", "quickfix" },
      }
    end,
  },

  -- Indent guides + current-scope line come from snacks.indent/snacks.scope
  -- (snacks.lua); mini.indentscope was removed — it drew the scope line a
  -- second time on every buffer.

  -- Rainbow brackets via Treesitter
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      require("rainbow-delimiters.setup").setup({
        -- Size guard: skip attach for files >1500 lines (checked at FileType attach time)
        condition = function(buf)
          return vim.api.nvim_buf_line_count(buf) <= 1500
        end,
      })
    end,
  },

  -- Inline color swatches for hex, rgb, hsl
  -- (catgoose fork — NvChad's repo was transferred here; it's the maintained one)
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPost",
    opts = {
      user_default_options = {
        css = true,
        tailwind = true,
        mode = "virtualtext",
      },
    },
  },

  -- Pretty inline diagnostics
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup({
        preset = "modern",
        options = {
          -- Name the server when several are attached (php = phpantom + laravel,
          -- ts = vtsls + typos_lsp + tailwind), so a message is attributable.
          show_source = { enabled = true, if_many = true },
          -- Diagnostics on lines other than the cursor line stay visible instead
          -- of vanishing until you land on them.
          multilines = { enabled = true, always_show = false },
        },
      })
    end,
  },

  -- Decorated scrollbar (diagnostics, git hunks, marks, search, cursor)
  {
    "lewis6991/satellite.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      current_only = true,
      winblend = 50,
      zindex = 40,
      excluded_filetypes = {
        "dashboard", "snacks_dashboard", "alpha", "starter",
        "help", "lazy", "mason", "TelescopeResults", "TelescopePrompt",
        "trouble", "Trouble", "oil", "undotree", "diff",
        "dap-view", "dap-view-term", "dap-repl",
        "noice", "checkhealth", "qf", "grug-far",
        "fugitive", "fugitiveblame", "git",
        "Avante",
      },
      handlers = {
        cursor      = { enable = true, overlap = true, priority = 1000 },
        search      = { enable = true, overlap = true, priority = 10 },
        diagnostic  = { enable = true, signs = { "-", "=", "≡" }, min_severity = vim.diagnostic.severity.WARN },
        gitsigns    = { enable = true, signs = { add = "│", change = "│", delete = "-" } },
        marks       = { enable = true, show_builtins = false, key = "m" },
        quickfix    = { enable = true, signs = { "-", "=", "≡" } },
      },
    },
    config = function(_, opts)
      require("satellite").setup(opts)
      -- Match transparent theme
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "SatelliteBar", { bg = "#30363d" })
          vim.api.nvim_set_hl(0, "SatelliteBackground", { bg = "NONE" })
        end,
      })
      pcall(function()
        vim.api.nvim_set_hl(0, "SatelliteBar", { bg = "#30363d" })
        vim.api.nvim_set_hl(0, "SatelliteBackground", { bg = "NONE" })
      end)
    end,
  },

  -- Colored function arguments via Treesitter
  {
    "m-demare/hlargs.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("hlargs").setup()
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
          if vim.api.nvim_buf_line_count(args.buf) > 1500 then
            require("hlargs").disable_buf(args.buf)
          end
        end,
      })
    end,
  },

  -- Wandering duck (:DuckHatch / :DuckCook)
  {
    "tamton-aquib/duck.nvim",
    cmd = { "DuckHatch", "DuckCook", "DuckKill", "DuckCookAll", "DuckKillAll" },
    keys = {
      -- winborder=rounded is global; temp-disable so duck floats spawn borderless
      { "<leader>udd", function()
          local p = vim.o.winborder; vim.o.winborder = "none"
          require("duck").hatch(); vim.o.winborder = p
        end, desc = "Hatch duck" },
      { "<leader>udk", function() require("duck").cook() end, desc = "Cook one duck" },
      { "<leader>uda", function()
          local p = vim.o.winborder; vim.o.winborder = "none"
          require("duck").hatch("🦆", 10); vim.o.winborder = p
        end, desc = "Hatch fast duck" },
      { "<leader>udK", function() require("duck").cook_all() end, desc = "Cook all ducks" },
    },
  },

  -- UI polish
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = {
      cmdline = {
        view = "cmdline", -- use inline cmdline to avoid E11 split errors in command-line window
      },
      lsp = {
        -- silent: noice's hover is a per-client handler (noice/lsp/hover.lua) run
        -- once per client via buf_request. On multi-client buffers (TS attaches
        -- typos_lsp + tailwindcss alongside vtsls) any client with no
        -- hover at the cursor fires `vim.notify("No information available")` even
        -- when another client returns real hover. Suppress that spurious notify.
        hover = { enabled = true, silent = true },
        signature = { enabled = false }, -- blink.cmp handles signature help
        message = { enabled = true },
        progress = { enabled = false },  -- fidget.nvim owns LSP progress
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      views = {
        -- Override noice default hover view (max_height=20, no border) which
        -- otherwise truncates long TypeScript signatures and shows '@@@' tail.
        hover = {
          size = { max_height = 40, max_width = 180 },
          border = { style = "rounded", padding = { 0, 1 } },
        },
      },
      presets = {
        long_message_to_split = true,
        -- Borders + FloatBorder:DiagnosticInfo on the hover/signature doc views,
        -- so LSP docs read as a distinct surface against the transparent bg.
        -- (views.hover above still wins on size — presets merge first.)
        lsp_doc_border = true,
        -- inc_rename is deliberately NOT enabled: that preset only styles the
        -- :IncRename cmdline, and inc-rename.nvim is not installed (rename goes
        -- through lua/config/rename.lua + snacks.rename).
      },
    },
  },

  -- Comfy line numbers: relative numbers using only easy-to-reach digits (1-5)
  {
    "mluders/comfy-line-numbers.nvim",
    event = "BufReadPre",
    opts = {
      labels = {
        "1", "2", "3", "4", "5", "11", "12", "13", "14", "15",
        "21", "22", "23", "24", "25", "31", "32", "33", "34", "35",
        "41", "42", "43", "44", "45", "51", "52", "53", "54", "55",
        "111", "112", "113", "114", "115", "121", "122", "123", "124", "125",
        "131", "132", "133", "134", "135", "141", "142", "143", "144", "145",
        "151", "152", "153", "154", "155",
      },
      up_key = "k",
      down_key = "j",
      hidden_file_types = { "undotree" },
      hidden_buffer_types = { "terminal", "nofile" },
    },
  },
}
