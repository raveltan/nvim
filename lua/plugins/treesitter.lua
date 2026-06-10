return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Defer to first file open. BufReadPre fires before FileType, so the FileType
    -- autocmd below is registered in time to highlight that same buffer. Saves
    -- startup cost on the dashboard (no buffer = no parser needed).
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "angular", "bash", "css", "dart", "embedded_template", "html", "javascript", "json", "lua",
        "markdown", "markdown_inline", "php", "php_only", "python", "regex",
        "ruby", "rust", "tsx", "typescript", "vim", "vimdoc", "yaml",
      })
      -- `angular` parser auto-injects into @Component({ template: `...` })
      -- backtick strings via nvim-treesitter's ecma/injections.scm — no extra
      -- query needed. The archived nvim-treesitter-angular plugin is NOT added
      -- (superseded by mainline injections).

      -- Filetypes whose runtime indent/<ft>.{vim,lua} beats treesitter's indents.scm.
      -- ruby/eruby: built-in GetRubyIndent handles continuations, hanging args,
      -- method chains, when/elsif, hash rockets — treesitter's query is minimal.
      local skip_ts_indent = { ruby = true, eruby = true }

      -- Enable treesitter highlighting and indentation for buffers with an available parser.
      -- Skip very large buffers (lines or bytes) to avoid slow parse on generated/minified files.
      local TS_MAX_BYTES = 500 * 1024
      local TS_MAX_LINES = 10000
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
        callback = function(args)
          local name = vim.api.nvim_buf_get_name(args.buf)
          local ok_stat, stat = pcall(vim.uv.fs_stat, name)
          if ok_stat and stat and stat.size and stat.size > TS_MAX_BYTES then return end
          if vim.api.nvim_buf_line_count(args.buf) > TS_MAX_LINES then return end
          pcall(vim.treesitter.start, args.buf)
          if vim.treesitter.get_parser(args.buf, nil, { error = false }) then
            if not skip_ts_indent[vim.bo[args.buf].filetype] then
              vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
            -- Native treesitter folding — window-local, buffer-scoped (vim.wo[0][0]),
            -- only for buffers WITH a parser, so the size guard above also skips folds.
            -- nvim-treesitter main does not auto-enable folds; we wire them here.
            vim.wo[0][0].foldmethod = "expr"
            vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
            vim.wo[0][0].foldlevel = 99 -- re-assert: folds enable after the window opened
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
      -- Per-buffer node stack: <BS> reverses <CR> one level; buffers don't share state.
      local stacks = {} -- bufnr -> { TSNode, ... }

      -- Treesitter ranges are end-exclusive; convert before setting (1,0)-indexed,
      -- inclusive visual marks. A node ending at (line_count, 0) (e.g. the root)
      -- would otherwise pass an out-of-range line to nvim_buf_set_mark.
      local function select_node(node)
        local sr, sc, er, ec = node:range()
        if ec == 0 then
          if er > 0 then
            er = er - 1
            ec = #vim.api.nvim_buf_get_lines(0, er, er + 1, true)[1]
          end
          if ec == 0 then ec = 1 end
        end
        local last = vim.api.nvim_buf_line_count(0)
        vim.api.nvim_buf_set_mark(0, "<", math.min(sr + 1, last), sc, {})
        vim.api.nvim_buf_set_mark(0, ">", math.min(er + 1, last), math.max(ec - 1, 0), {})
        vim.cmd("normal! gv")
      end

      map("n", "<CR>", function()
        -- Pass <CR> through in the cmdwin (q:, q/) and special buffers
        -- (quickfix, terminal, help, prompt) where <CR> has a real default.
        if vim.fn.win_gettype() == "command" or vim.bo.buftype ~= "" then
          return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end
        local node = vim.treesitter.get_node()
        if node then
          stacks[vim.api.nvim_get_current_buf()] = { node }
          select_node(node)
        end
      end, { desc = "Start incremental select" })

      map("x", "<CR>", function()
        local stack = stacks[vim.api.nvim_get_current_buf()]
        local current = stack and stack[#stack]
        if current then
          local parent = current:parent()
          if parent then
            stack[#stack + 1] = parent
            select_node(parent)
          end
        end
      end, { desc = "Expand selection" })

      map("x", "<BS>", function()
        local stack = stacks[vim.api.nvim_get_current_buf()]
        if stack and #stack > 1 then
          table.remove(stack)
          select_node(stack[#stack])
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
