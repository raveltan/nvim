local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Sync real yanks (y only — not d/c/x) to the macOS clipboard. Replaces
-- clipboard=unnamedplus: the pbcopy/pbpaste provider is uncached on macOS, so
-- unnamedplus spawned a synchronous process per delete/change/put (100@q of dd
-- measured ~912ms vs 0.4ms without; yanky's p paid an extra getreg("+")
-- pbpaste per put). Paste from other apps with "+p; yanky's FocusGained
-- ring-sync still captures external copies.
autocmd("TextYankPost", {
  group = augroup("yank_to_clipboard", { clear = true }),
  callback = function()
    if vim.v.event.operator == "y" and vim.v.event.regname == "" then
      vim.fn.setreg("+", vim.fn.getreg('"'), vim.fn.getregtype('"'))
    end
  end,
})

-- Auto-resize splits on window resize
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Auto-create parent directories on save
autocmd("BufWritePre", {
  group = augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Go to last cursor position when opening file
autocmd("BufReadPost", {
  group = augroup("last_cursor_position", { clear = true }),
  callback = function(event)
    -- Skip commit/rebase messages (stale position from last commit) and
    -- special buffers.
    local ft = vim.bo[event.buf].filetype
    if vim.bo[event.buf].buftype ~= "" or ft == "gitcommit" or ft == "gitrebase" then return end
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Keep ]] / [[ as universal "next/prev occurrence of word under cursor" (text
-- search). Many runtime ftplugins (ruby, python, rust, markdown, go, eruby, …)
-- map [[/]] buffer-locally to class/section motions, shadowing the global maps
-- in config/keymaps.lua. This FileType autocmd runs after those ftplugins, so
-- re-asserting the buffer-local maps wins everywhere.
autocmd("FileType", {
  group = augroup("universal_word_search", { clear = true }),
  callback = function(ev)
    -- Real file buffers only; qf/help/terminal/prompt keep their own [[ ]].
    -- Scheduled: for :help buffers buftype is set *after* FileType fires.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype ~= "" then return end
      local search_cword = require("util.wordsearch").search_cword
      vim.keymap.set("n", "]]", function() search_cword("n") end,
        { buffer = ev.buf, desc = "Next occurrence of word (text search)" })
      vim.keymap.set("n", "[[", function() search_cword("N") end,
        { buffer = ev.buf, desc = "Prev occurrence of word (text search)" })
    end)
  end,
})

-- Close specific filetypes with q
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "qf", "lspinfo", "man", "notify", "checkhealth", "grug-far", "gitsigns-blame" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Buffer-local neotest keymaps (plain user config; pressing one lazy-loads
-- neotest via lazy.nvim's module autoloader on require("neotest")). Lived in
-- the neotest spec's config() before, which forced an ft trigger that loaded
-- neotest + 7 adapters (~68ms) on every file open.
autocmd("FileType", {
  group = augroup("neotest_keys", { clear = true }),
  pattern = { "php", "typescript", "javascript", "python", "ruby", "dart", "rust" },
  callback = function(ev)
    local buf, ft = ev.buf, ev.match
    local o = { buffer = buf, silent = true }
    vim.keymap.set("n", "<leader>tr", function() require("neotest").run.run() end, vim.tbl_extend("force", o, { desc = "Run nearest test" }))
    vim.keymap.set("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, vim.tbl_extend("force", o, { desc = "Run file tests" }))
    vim.keymap.set("n", "<leader>tc", function() require("config.neotest-coverage").run_current() end, vim.tbl_extend("force", o, { desc = "Run file tests with coverage" }))
    vim.keymap.set("n", "<leader>td", function()
      require("dap") -- force-load so per-filetype dap.configurations are populated
      require("neotest").run.run({ strategy = "dap" })
    end, vim.tbl_extend("force", o, { desc = "Debug nearest test" }))
    if ft == "ruby" then
      vim.keymap.set("n", "<leader>tp", function() require("config.neotest-profile-ruby").run_current() end,
        vim.tbl_extend("force", o, { desc = "Profile file tests (stackprof)" }))
    end
    if vim.g.gaf then require("gaf.test").attach_keys(buf, ft) end
  end,
})
