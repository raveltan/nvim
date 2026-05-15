return {
  -- Git signs (gutter, blame, hunk actions)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "┃" },
          change = { text = "┃" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        current_line_blame = true,
        current_line_blame_opts = {
          delay = 2000,
          virt_text_pos = "eol",
        },
        current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
        on_attach = function(bufnr)
          local gs = require("gitsigns")

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation (with diff mode fallback)
          map("n", "]c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gs.nav_hunk("next")
            end
          end, { desc = "Next hunk" })

          map("n", "[c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gs.nav_hunk("prev")
            end
          end, { desc = "Prev hunk" })

          -- Blame
          map("n", "<leader>gb", function() gs.blame() end, { desc = "Blame file (author column)" })
          map("n", "<leader>gt", gs.toggle_current_line_blame, { desc = "Toggle line blame virt text" })
        end,
      })
    end,
  },

  -- Visual merge-conflict resolution (co/ct/cb/c0, ]x/[x)
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "BufReadPre",
    config = true,
  },

  -- Git diff viewer
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
      { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
    opts = {
      view = {
        merge_tool = { layout = "diff3_mixed" },
      },
    },
  },

  -- Fugitive: line history, interactive blame, GBrowse permalinks
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gclog", "Gdiffsplit", "Gedit", "Gread", "Gwrite", "Ggrep" },
    keys = {
      {
        "<leader>gl",
        function() require("util.line_history").pick() end,
        desc = "Line history",
      },
      {
        "<leader>gl",
        function()
          local s = vim.fn.line("v")
          local e = vim.fn.line(".")
          if s > e then s, e = e, s end
          vim.cmd("normal! \27")
          require("util.line_history").pick(s, e)
        end,
        mode = "v",
        desc = "Range history",
      },
      { "<leader>gB", "<cmd>Git blame<cr>", desc = "Blame interactive" },
      { "<leader>g/", function() require("util.ggrep").prompt() end, desc = "Git grep (prompt)" },
      { "<leader>g*", function() require("util.ggrep").cword() end, desc = "Git grep word under cursor" },
      { "<leader>g/", function() require("util.ggrep").visual() end, mode = "v", desc = "Git grep selection" },
    },
  },

}
