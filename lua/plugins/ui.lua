return {
  -- Colorscheme
  {
    "scottmckendry/cyberdream.nvim",
    name = "cyberdream",
    priority = 1000,
    lazy = false,
    config = function()
      require("cyberdream").setup({
        transparent = true,
        italic_comments = true,
      })
      vim.cmd.colorscheme("cyberdream")

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
        theme = "cyberdream",
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
