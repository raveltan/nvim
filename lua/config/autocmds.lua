local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- ─────────────────────────────────────────────────────────────────────────────
-- Workaround: nvim 0.12.x LSP hover float shrinks too aggressively after
-- treesitter conceal_lines hides markdown code-fence rows.
--
-- Bug chain (vim/lsp/util.lua open_floating_preview, ~line 1769-1781):
--   1. float is created and vim.treesitter.start(buf) attaches markdown queries
--   2. queries set `conceal_lines ""` on fenced_code_block nodes
--   3. nvim_win_text_height counts post-conceal rows -> under-reports
--   4. `if text_height < win_height then nvim_win_set_height(win, text_height)`
--      shrinks the window before wrapped content can render
--   5. long wrapped lines (e.g. typescript signatures) get clipped
--
-- This wrapper forces a redraw between window creation and the height check
-- so nvim_win_text_height returns the true rendered row count, then resizes
-- the window UP to fit content rather than down. Same approach as upstream
-- PR #32662 (which fixed the inverse direction for conceal_lines).
--
-- Upstream tracking: neovim/neovim#32607 (introduced shrink path),
--                    neovim/neovim#32639, neovim/neovim#32662 (partial fixes).
--
-- TO REMOVE THIS WORKAROUND:
--   Periodically check the upstream issues above. When a release notes entry
--   confirms the truncation case is fixed (likely in 0.12.x point release or
--   0.13), delete this entire `do ... end` block and verify hover on a long
--   TypeScript signature still renders fully.
-- ─────────────────────────────────────────────────────────────────────────────
do
  local orig = vim.lsp.util.open_floating_preview
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
    local buf, win = orig(contents, syntax, opts)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim__redraw({ win = win, valid = true, flush = true })
      local rendered = vim.api.nvim_win_text_height(win, {}).all
      if rendered > vim.api.nvim_win_get_height(win) then
        vim.api.nvim_win_set_height(win, rendered)
      end
    end
    return buf, win
  end
end

-- Auto-dismiss swap file dialog (E325) — snacks picker opens files non-interactively
autocmd("SwapExists", {
  group = augroup("swap_exists", { clear = true }),
  callback = function() vim.v.swapchoice = "e" end,
})

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
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
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Disable relativenumber on large files (>2000 lines) — redraws on every cursor move
autocmd("BufReadPost", {
  group = augroup("no_relnum_large_file", { clear = true }),
  callback = function()
    if vim.api.nvim_buf_line_count(0) > 2000 then
      vim.wo.relativenumber = false
    end
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
