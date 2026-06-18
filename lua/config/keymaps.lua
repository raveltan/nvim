local map = vim.keymap.set

-- Window splits
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Buffer
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<cr>", { desc = "Close other buffers" })

-- Window resize submode: press <leader>ur, then h/j/k/l (shift = bigger step), = to equalize, Esc/q to exit
local function resize_submode()
  local hint = "-- RESIZE -- h/l: width  j/k: height  H/J/K/L: x5  =: equal  q/<Esc>: quit"
  while true do
    vim.cmd("redraw")
    vim.api.nvim_echo({ { hint, "ModeMsg" } }, false, {})
    local ok, c = pcall(vim.fn.getcharstr)
    if not ok then break end
    if c == "h" then vim.cmd("vertical resize -2")
    elseif c == "l" then vim.cmd("vertical resize +2")
    elseif c == "j" then vim.cmd("resize -2")
    elseif c == "k" then vim.cmd("resize +2")
    elseif c == "H" then vim.cmd("vertical resize -10")
    elseif c == "L" then vim.cmd("vertical resize +10")
    elseif c == "J" then vim.cmd("resize -10")
    elseif c == "K" then vim.cmd("resize +10")
    elseif c == "=" then vim.cmd("wincmd =")
    else break end
  end
  vim.api.nvim_echo({ { "" } }, false, {})
end
map("n", "<leader>ur", resize_submode, { desc = "Resize submode (hjkl)" })

-- Clear search highlights
map("n", "<esc>", "<cmd>noh<cr><esc>", { desc = "Clear highlights" })

-- Terminal: double-Esc exits terminal mode (single Esc still passes through to TUI apps)
map("t", "<esc><esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- LSP / Code actions (<leader>ca handled by actions-preview.nvim plugin spec)
map("n", "<leader>cA", function()
  vim.lsp.buf.code_action({ context = { only = { "source" }, diagnostics = {} } })
end, { desc = "Source action" })
map("n", "<leader>cr", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })
  if #clients == 0 then
    vim.notify("No LSP client supports rename", vim.log.levels.WARN)
    return
  end
  local client = clients[1]

  -- PHP/intelephense: rename range starts after `$` sigil. If cursor sits on `$`, advance one column.
  if vim.bo[bufnr].filetype == "php" then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    if line:sub(col + 1, col + 1) == "$" then
      vim.api.nvim_win_set_cursor(0, { row, col + 1 })
    end
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local cword = vim.fn.expand("<cword>")
  local is_php = vim.bo[bufnr].filetype == "php"
  local php_is_var = false
  if is_php then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    -- Look backward from cursor for `$` immediately preceding the identifier
    local before = line:sub(1, col + 1)
    if before:match("%$[%w_]*$") then
      php_is_var = true
    end
    cword = cword:gsub("^%$", "")
  end

  vim.ui.input({ prompt = "Rename: ", default = cword }, function(new_name)
    if not new_name or new_name == "" then return end
    if is_php then
      new_name = new_name:gsub("^%$", "")
    end
    if new_name == cword then return end
    if php_is_var then
      params.newName = "$" .. new_name
    else
      params.newName = new_name
    end
    client:request("textDocument/rename", params, function(err, result)
      if err then
        vim.notify(string.format("Rename failed: %s (code=%s data=%s)",
          err.message, tostring(err.code), vim.inspect(err.data)), vim.log.levels.ERROR)
        return
      end
      if not result then
        vim.notify("Language server returned no rename result", vim.log.levels.WARN)
        return
      end
      vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
      vim.cmd("silent! wall")
    end, bufnr)
  end)
end, { desc = "Rename symbol" })
-- Wrap in a closure: keymaps.lua runs at startup (init.lua), but noice swaps
-- `vim.lsp.buf.hover` for its styled view later on VeryLazy. Binding the bare
-- reference here captures the native float (plain markdown, ugly since markview
-- skips `nofile`). The closure dereferences at call-time, so K hits noice.
map("n", "K", function() vim.lsp.buf.hover() end, { desc = "Hover docs" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })

-- Quickfix list navigation (wraps around; centers cursor line)
local function qf_jump(forward)
  if not pcall(vim.cmd, forward and "cnext" or "cprev") then
    pcall(vim.cmd, forward and "cfirst" or "clast")
  end
  vim.cmd("normal! zz")
end
map("n", "]q", function() qf_jump(true) end, { desc = "Next quickfix item" })
map("n", "[q", function() qf_jump(false) end, { desc = "Prev quickfix item" })
map("n", "]Q", "<cmd>silent! clast<cr>zz", { desc = "Last quickfix item" })
map("n", "[Q", "<cmd>silent! cfirst<cr>zz", { desc = "First quickfix item" })

-- Inlay hints toggle
map("n", "<leader>ci", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-- Case conversion via vim-abolish (operates on word under cursor).
-- One picker → choose target case, feeds the abolish `cr{x}iw` coercion.
map("n", "<leader>cv", function()
  local cases = {
    { label = "snake_case", key = "s" },
    { label = "camelCase",  key = "c" },
    { label = "PascalCase", key = "m" },
    { label = "UPPER_CASE", key = "u" },
    { label = "kebab-case", key = "-" },
    { label = "dot.case",   key = "." },
    { label = "Title Case", key = "t" },
  }
  vim.ui.select(cases, {
    prompt = "Convert case:",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    -- "m" (remap) so vim-abolish's `cr` coercion operator is honored
    vim.api.nvim_feedkeys("cr" .. choice.key .. "iw", "m", false)
  end)
end, { desc = "Convert case (picker)" })

-- Better indentation (keep selection)
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Paste over selection without clobbering the unnamed register (default in visual mode)
map("x", "p", [["_dP]], { desc = "Paste without overwrite" })

-- Location list (quickfix toggle lives in the quicker.nvim spec → <leader>xq)
map("n", "<leader>xl", function()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.loclist == 1 then
      vim.cmd.lclose()
      return
    end
  end
  pcall(vim.cmd.lopen)
end, { desc = "Toggle loclist" })

-- Center after jumps
map("n", "<C-d>", "15jzz", { desc = "Small jump down (centered)" })
map("n", "<C-u>", "15kzz", { desc = "Small jump up (centered)" })
map("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Next search result (centered)" })
map("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Prev search result (centered)" })

-- ]] / [[ — jump to next/prev occurrence of the word under cursor via plain
-- text search (no LSP). See util.wordsearch. These are the baseline (global)
-- maps; many runtime ftplugins (ruby, python, rust, markdown, go, …) rebind
-- [[/]] buffer-locally to section motions, so a FileType autocmd in
-- config/autocmds.lua re-asserts these per buffer to keep them universal.
local search_cword = require("util.wordsearch").search_cword
map("n", "]]", function() search_cword("n") end, { desc = "Next occurrence of word (text search)" })
map("n", "[[", function() search_cword("N") end, { desc = "Prev occurrence of word (text search)" })

-- Join without moving cursor
map("n", "J", "mzJ`z", { desc = "Join lines" })

-- Open URL/file under cursor (Phabricator-aware under the GAF profile)
map("n", "gx", function()
  if vim.g.gaf and require("gaf.keymaps").open_phab_under_cursor() then return end
  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then vim.ui.open(cfile) end
end, { desc = "Open URL/file under cursor" })
