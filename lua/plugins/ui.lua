return {
  -- Colorscheme
  {
    "luisiacc/gruvbox-baby",
    priority = 1000,
    lazy = false,
    config = function()
      vim.cmd.colorscheme("gruvbox-baby")

      -- Clear backgrounds for full terminal transparency
      local transparent_groups = {
        "Normal",
        "NormalNC",
        "NormalFloat",
        "SignColumn",
        "StatusLine",
        "StatusLineNC",
        "FloatBorder",
        "WinSeparator",
      }
      for _, group in ipairs(transparent_groups) do
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", vim.api.nvim_get_hl(0, { name = group }), { bg = "NONE" }))
      end
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
    dependencies = { "echasnovski/mini.icons" },
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
          theme = "gruvbox-baby",
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
            { "filename", path = 0, symbols = { modified = "  ", readonly = " ", unnamed = " " } },
            macro,
          },
          lualine_x = { lsp, encoding, fileformat },
          lualine_y = { "progress" },
          lualine_z = { { "location", icon = "" } },
        },
        extensions = { "lazy", "mason", "neo-tree", "trouble", "quickfix" },
      }
    end,
  },

  -- Indent scope (animation disabled — quadratic redraw per cursor move was a CPU sink)
  {
    "echasnovski/mini.indentscope",
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      return {
        symbol = "│",
        options = { try_as_border = true },
        draw = {
          animation = function() return 0 end,
        },
      }
    end,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help", "alpha", "dashboard", "neo-tree", "Trouble", "trouble",
          "lazy", "mason", "notify", "toggleterm", "lazyterm", "snacks_dashboard",
          "satellite", "undotree", "diff", "dap-view", "dap-view-term", "dap-repl",
        },
        callback = function() vim.b.miniindentscope_disable = true end,
      })
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function()
          if vim.api.nvim_buf_line_count(0) > 1500 then
            vim.b.miniindentscope_disable = true
          end
        end,
      })
    end,
  },

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
  {
    "NvChad/nvim-colorizer.lua",
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
        preset = "powerline",
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
        "markview", "Avante",
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
        hover = { enabled = true },
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
