return {
  -- Colorscheme
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    priority = 1000,
    lazy = false,
    config = function()
      require("github-theme").setup({
        options = {
          transparent = true,
          styles = { comments = "italic" },
        },
      })
      vim.cmd.colorscheme("github_dark_high_contrast")

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

      local search = {
        function()
          local ok, s = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
          if not ok or not s or s.total == 0 then return "" end
          return string.format(" [%d/%d]", s.current, s.total)
        end,
        cond = function() return vim.v.hlsearch == 1 end,
      }

      local selection = {
        function()
          local m = vim.fn.mode()
          if not m:find("[vV\22]") then return "" end
          local s_line, e_line = vim.fn.line("v"), vim.fn.line(".")
          local lines = math.abs(e_line - s_line) + 1
          local chars = vim.fn.wordcount().visual_chars or 0
          return " " .. lines .. "L " .. chars .. "C"
        end,
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

      -- Refresh on macro start/stop + mode change for snappy updates
      vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave", "ModeChanged" }, {
        callback = function() require("lualine").refresh() end,
      })

      return {
        options = {
          theme = "github_dark_high_contrast",
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
            search,
          },
          lualine_x = { selection, lsp, encoding, fileformat, "filetype" },
          lualine_y = { "progress" },
          lualine_z = { { "location", icon = "" } },
        },
        extensions = { "lazy", "mason", "neo-tree", "trouble", "quickfix" },
      }
    end,
  },

  -- Cursor trail (smear)
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.5,
      hide_target_hack = false,
    },
  },

  -- Indent scope animation
  {
    "echasnovski/mini.indentscope",
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      return {
        symbol = "│",
        options = { try_as_border = true },
        draw = {
          animation = require("mini.indentscope").gen_animation.quadratic({
            easing = "out",
            duration = 80,
            unit = "total",
          }),
        },
      }
    end,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help", "alpha", "dashboard", "neo-tree", "Trouble", "trouble",
          "lazy", "mason", "notify", "toggleterm", "lazyterm", "snacks_dashboard",
        },
        callback = function() vim.b.miniindentscope_disable = true end,
      })
    end,
  },

  -- Rainbow brackets via Treesitter
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      require("rainbow-delimiters.setup").setup({})
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

  -- Distraction-free coding
  {
    "folke/zen-mode.nvim",
    keys = {
      { "<leader>uz", "<cmd>ZenMode<cr>", desc = "Zen mode" },
    },
    opts = {
      window = { width = 120 },
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
}
