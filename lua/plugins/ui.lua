return {
  -- Colorscheme
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    lazy = false,
    config = function()
      require("rose-pine").setup({
        variant = "main",
        palette = {
          main = {
            base = "#15141b",
            surface = "#1f1d28",
            overlay = "#29263c",
          },
        },
        styles = {
          transparency = true,
        },
      })
      vim.cmd.colorscheme("rose-pine")

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
    opts = {
      options = {
        theme = "rose-pine",
        globalstatus = true,
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- Minimal, beautiful bufferline
  {
    "willothy/nvim-cokeline",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<S-h>", "<Plug>(cokeline-focus-prev)", desc = "Prev buffer" },
      { "<S-l>", "<Plug>(cokeline-focus-next)", desc = "Next buffer" },
      { "<leader>bp", "<Plug>(cokeline-pick-focus)", desc = "Pick buffer" },
    },
    config = function()
      local get_hex = require("cokeline.hlgroups").get_hl_attr
      require("cokeline").setup({
        default_hl = {
          fg = function(buffer)
            return buffer.is_focused and get_hex("Normal", "fg") or get_hex("Comment", "fg")
          end,
          bg = "NONE",
        },
        components = {
          { text = " " },
          {
            text = function(buffer) return (buffer.devicon.icon or "") .. " " end,
            fg = function(buffer) return buffer.devicon.color end,
          },
          { text = function(buffer) return buffer.filename .. " " end,
            bold = function(buffer) return buffer.is_focused end },
          {
            text = function(buffer) return buffer.is_modified and "● " or "  " end,
            fg = function(buffer) return buffer.is_modified and "#f6c177" or nil end,
          },
        },
      })
    end,
  },

  -- TODO/FIX/NOTE highlighting
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo comments" },
    },
  },

  -- Code chunk / scope highlighting
  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      chunk = { enable = true, style = "#c4a7e7" },
      indent = { enable = false }, -- snacks.indent handles this
      line_num = { enable = true, style = "#c4a7e7" },
      blank = { enable = false },
    },
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

  -- Minimap
  {
    "echasnovski/mini.map",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      { "<leader>um", function() require("mini.map").toggle() end, desc = "Toggle minimap" },
    },
    config = function()
      local map = require("mini.map")
      map.setup({
        integrations = {
          map.gen_integration.diagnostic(),
          map.gen_integration.builtin_search(),
          map.gen_integration.diff(),
        },
        symbols = {
          encode = map.gen_encode_symbols.dot("4x2"),
        },
        window = {
          focusable = false,
          width = 15,
          winblend = 0,
        },
      })
      map.close()
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
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
        hover = {
          enabled = true,
          opts = {
            size = { max_width = 80, max_height = 25 },
          },
        },
        signature = {
          enabled = false, -- blink.cmp handles signature help
        },
      },
      presets = {
        lsp_doc_border = true,
        long_message_to_split = true,
      },
    },
  },
}
