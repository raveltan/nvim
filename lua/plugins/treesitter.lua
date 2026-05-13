return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "angular", "bash", "css", "eruby", "html", "javascript", "json", "lua",
        "markdown", "markdown_inline", "php", "php_only", "python", "regex",
        "ruby", "tsx", "typescript", "vim", "vimdoc", "yaml",
      })
      -- `angular` parser auto-injects into @Component({ template: `...` })
      -- backtick strings via nvim-treesitter's ecma/injections.scm — no extra
      -- query needed. The archived nvim-treesitter-angular plugin is NOT added
      -- (superseded by mainline injections).

      -- Filetypes whose runtime indent/<ft>.{vim,lua} beats treesitter's indents.scm.
      -- ruby/eruby: built-in GetRubyIndent handles continuations, hanging args,
      -- method chains, when/elsif, hash rockets — treesitter's query is minimal.
      local skip_ts_indent = { ruby = true, eruby = true }

      -- Enable treesitter highlighting and indentation for buffers with an available parser
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          if not skip_ts_indent[vim.bo[args.buf].filetype]
            and vim.treesitter.get_parser(args.buf, nil, { error = false }) then
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
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      local map = vim.keymap.set

      -- Select textobjects (second arg names the query file: textobjects.scm)
      map({ "x", "o" }, "af", function() select.select_textobject("@function.outer", "textobjects") end, { desc = "Around function" })
      map({ "x", "o" }, "if", function() select.select_textobject("@function.inner", "textobjects") end, { desc = "Inside function" })
      map({ "x", "o" }, "ac", function() select.select_textobject("@class.outer", "textobjects") end, { desc = "Around class" })
      map({ "x", "o" }, "ic", function() select.select_textobject("@class.inner", "textobjects") end, { desc = "Inside class" })
      map({ "x", "o" }, "aa", function() select.select_textobject("@parameter.outer", "textobjects") end, { desc = "Around argument" })
      map({ "x", "o" }, "ia", function() select.select_textobject("@parameter.inner", "textobjects") end, { desc = "Inside argument" })

      -- Move to next/prev
      map({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function" })
      map({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Prev function" })
      map({ "n", "x", "o" }, "]a", function() move.goto_next_start("@parameter.outer", "textobjects") end, { desc = "Next argument" })
      map({ "n", "x", "o" }, "[a", function() move.goto_previous_start("@parameter.outer", "textobjects") end, { desc = "Prev argument" })

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
