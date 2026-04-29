return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    init = function()
      -- Register blade filetype early so FileType autocmds fire correctly
      vim.filetype.add({
        pattern = {
          [".*%.blade%.php"] = "blade",
        },
      })
    end,
    config = function()
      require("nvim-treesitter").install({
        "bash", "css", "eruby", "html", "javascript", "json", "lua",
        "markdown", "markdown_inline", "php", "php_only", "python", "regex",
        "ruby", "tsx", "typescript", "vim", "vimdoc", "yaml",
      })

      -- Enable treesitter highlighting and indentation for buffers with an available parser
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          -- Enable treesitter-based indentation
          if vim.treesitter.get_parser(args.buf, nil, { error = false }) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Enable matchup treesitter integration
      vim.g.matchup_matchparen_deferred = 1
    end,
  },

  -- Sticky context (shows function/class at top of screen)
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      max_lines = 3,
    },
  },

  -- Treesitter textobjects
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")
      local config = require("nvim-treesitter-textobjects.config")

      config.update({ select = { lookahead = true } })

      local map = vim.keymap.set

      -- Select textobjects
      map({ "x", "o" }, "af", function() select.select_textobject("@function.outer") end, { desc = "Around function" })
      map({ "x", "o" }, "if", function() select.select_textobject("@function.inner") end, { desc = "Inside function" })
      map({ "x", "o" }, "ac", function() select.select_textobject("@class.outer") end, { desc = "Around class" })
      map({ "x", "o" }, "ic", function() select.select_textobject("@class.inner") end, { desc = "Inside class" })
      map({ "x", "o" }, "aa", function() select.select_textobject("@parameter.outer") end, { desc = "Around argument" })
      map({ "x", "o" }, "ia", function() select.select_textobject("@parameter.inner") end, { desc = "Inside argument" })

      -- Move to next/prev
      map({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer") end, { desc = "Next function" })
      map({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer") end, { desc = "Prev function" })
      map({ "n", "x", "o" }, "]a", function() move.goto_next_start("@parameter.outer") end, { desc = "Next argument" })
      map({ "n", "x", "o" }, "[a", function() move.goto_previous_start("@parameter.outer") end, { desc = "Prev argument" })

      -- Swap
      map("n", "<leader>csa", function() swap.swap_next("@parameter.inner") end, { desc = "Swap with next arg" })
      map("n", "<leader>csA", function() swap.swap_previous("@parameter.inner") end, { desc = "Swap with prev arg" })

      -- Incremental selection (expand/shrink by syntax node)
      local current_node = nil
      map("n", "<CR>", function()
        current_node = vim.treesitter.get_node()
        if current_node then
          local sr, sc, er, ec = current_node:range()
          vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
          vim.api.nvim_buf_set_mark(0, ">", er + 1, ec - 1, {})
          vim.cmd("normal! gv")
        end
      end, { desc = "Start incremental select" })

      map("x", "<CR>", function()
        if current_node then
          local parent = current_node:parent()
          if parent then
            current_node = parent
            local sr, sc, er, ec = current_node:range()
            vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
            vim.api.nvim_buf_set_mark(0, ">", er + 1, ec - 1, {})
            vim.cmd("normal! gv")
          end
        end
      end, { desc = "Expand selection" })

      map("x", "<BS>", function()
        if current_node then
          local child = vim.treesitter.get_node()
          if child and child ~= current_node then
            current_node = child
            local sr, sc, er, ec = current_node:range()
            vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
            vim.api.nvim_buf_set_mark(0, ">", er + 1, ec - 1, {})
            vim.cmd("normal! gv")
          end
        end
      end, { desc = "Shrink selection" })
    end,
  },

  -- Auto-close and auto-rename HTML/JSX tags
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    opts = {},
  },
}
