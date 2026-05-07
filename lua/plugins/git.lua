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
          delay = 300,
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

          -- Stage / Reset
          map("n", "<leader>ghs", gs.stage_hunk, { desc = "Stage hunk" })
          map("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset hunk" })
          map("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage hunk" })
          map("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Reset hunk" })
          map("n", "<leader>ghS", gs.stage_buffer, { desc = "Stage buffer" })
          map("n", "<leader>ghR", gs.reset_buffer, { desc = "Reset buffer" })
          -- gs.stage_hunk on a staged hunk now toggles (unstages); reuse for "undo".
          map("n", "<leader>ghu", gs.stage_hunk, { desc = "Toggle stage hunk (unstage)" })

          -- Preview / Diff
          map("n", "<leader>ghp", gs.preview_hunk, { desc = "Preview hunk" })
          map("n", "<leader>ghd", function() gs.diffthis() end, { desc = "Diff this" })
          map("n", "<leader>ghD", function() gs.diffthis("~") end, { desc = "Diff against last commit" })

          -- Blame
          map("n", "<leader>gb", function() gs.blame() end, { desc = "Blame file" })
          map("n", "<leader>gB", function() gs.blame_line({ full = true }) end, { desc = "Blame line (full commit)" })

          -- Close git view (diff/blame) and return to file
          map("n", "<leader>gq", function()
            -- Find the original buffer (non-diff, modifiable file)
            local target_win = nil
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              local bt = vim.bo[buf].buftype
              local name = vim.api.nvim_buf_get_name(buf)
              if bt == "" and name ~= "" and not vim.startswith(name, "gitsigns://") then
                target_win = win
              end
            end
            if target_win then
              vim.api.nvim_set_current_win(target_win)
            end
            vim.cmd("diffoff!")
            vim.cmd("only")
          end, { desc = "Close git view" })

          -- Text object (select hunk)
          map({ "o", "x" }, "ih", gs.select_hunk, { desc = "Select hunk" })
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
      { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
    },
    opts = {
      view = {
        merge_tool = { layout = "diff3_mixed" },
      },
    },
  },
}
