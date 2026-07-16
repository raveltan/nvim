return {
  -- Git signs (gutter, blame, hunk actions)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "/" },
          delete = { text = "-" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
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
            vim.cmd("normal! zz") -- center the jumped-to hunk
          end, { desc = "Next hunk" })

          map("n", "[c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gs.nav_hunk("prev")
            end
            vim.cmd("normal! zz") -- center the jumped-to hunk
          end, { desc = "Prev hunk" })

          -- Hunk actions — promoted to <leader>g (inline preview + reset only)
          map("n", "<leader>gb", function() require("util.blame").blame("diff") end, { desc = "Blame line (diff)" })
          map("n", "<leader>gB", function() require("util.blame").blame("message") end, { desc = "Blame line (message)" })
          map("n", "<leader>gp", gs.preview_hunk_inline, { desc = "Preview hunk (inline)" })
          map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
          map("v", "<leader>gr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, { desc = "Reset selected lines" })
        end,
      })
    end,
  },

  -- Merge-conflict resolution, promoted to <leader>gc (which-key group)
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "BufReadPre",
    opts = { default_mappings = false },
    keys = {
      { "<leader>gco", "<cmd>GitConflictChooseOurs<cr>",   desc = "Choose ours" },
      { "<leader>gct", "<cmd>GitConflictChooseTheirs<cr>", desc = "Choose theirs" },
      { "<leader>gcb", "<cmd>GitConflictChooseBoth<cr>",   desc = "Choose both" },
      { "<leader>gc0", "<cmd>GitConflictChooseNone<cr>",   desc = "Choose none" },
      { "<leader>gcn", "<cmd>GitConflictNextConflict<cr>", desc = "Next conflict" },
      { "<leader>gcp", "<cmd>GitConflictPrevConflict<cr>", desc = "Prev conflict" },
      { "<leader>gcq", "<cmd>GitConflictListQf<cr>",       desc = "List conflicts (quickfix)" },
    },
  },

  -- Fugitive: line history, file history, and file diff
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
      { "<leader>gf", function() require("util.line_history").file() end, desc = "File history (current file)" },
      { "<leader>gd", "<cmd>Gdiffsplit<cr>", desc = "Diff current file vs index" },
    },
  },

}
