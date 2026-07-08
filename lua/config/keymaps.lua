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
  -- Context-smart: CSS class under cursor → buffer-wide class rename; tag name under
  -- cursor → tagmatch pair rename; anything else → LSP symbol rename below.
  local rename = require("config.rename")
  if rename.class_rename() then return end
  if rename.tag_rename() then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })
  if #clients == 0 then
    vim.notify("No LSP client supports rename", vim.log.levels.WARN)
    return
  end
  local client = clients[1]

  -- PHP/intelephense: rename range starts after `$` sigil. If cursor sits on `$`,
  -- advance one column (restored below if the rename is cancelled).
  local orig_cursor = nil
  if vim.bo[bufnr].filetype == "php" then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    if line:sub(col + 1, col + 1) == "$" then
      orig_cursor = { row, col }
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
    local function restore_cursor()
      if orig_cursor then pcall(vim.api.nvim_win_set_cursor, 0, orig_cursor) end
    end
    if not new_name or new_name == "" then return restore_cursor() end
    if is_php then
      new_name = new_name:gsub("^%$", "")
    end
    if new_name == cword then return restore_cursor() end
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

-- Quickfix operators: act on the whole list, not one entry at a time.
-- Typical flow: <leader>sg grep → <C-q> (fff/snacks send to qf) → <leader>xr.
-- Find/replace across every qf entry, saving each touched file (:cdo … | update).
map("n", "<leader>xr", function()
  if vim.fn.getqflist({ size = 0 }).size == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.WARN)
    return
  end
  local pat = vim.fn.input("cdo s/")
  if pat == "" then return end
  -- pcall: a bad pattern or zero substitutions on an entry shouldn't abort the run.
  pcall(vim.cmd, "cdo s/" .. pat .. " | update")
end, { desc = "Replace across quickfix (:cdo)" })
-- Dump all project diagnostics into the quickfix list (walkable with ]q, editable via quicker).
map("n", "<leader>xd", function() vim.diagnostic.setqflist() end, { desc = "Diagnostics → quickfix" })
-- All TODO/FIX/HACK comments → quickfix (todo-comments.nvim registers the command on VeryLazy).
map("n", "<leader>xt", "<cmd>TodoQuickFix<cr>", { desc = "TODOs → quickfix" })

-- Inlay hints toggle
map("n", "<leader>ci", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-- Case conversion
map("n", "<leader>cv", function()
  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win) -- (row, col) 1-based row, 0-based col
  local row, col = pos[1] - 1, pos[2]
  local line = vim.api.nvim_get_current_line()

  -- Identify the full identifier under the cursor, including separators (`-`,
  -- `_`). text-case's current_word() operates on `aw`/<cword>, which stops at
  -- `-`, so a kebab-case token like `hello-world` is only seen as `hello`.
  -- We extract the whole [%w_-] run ourselves and convert the raw string.
  local function is_tok(c) return c ~= "" and c:match("[%w_%-]") ~= nil end
  local s = col -- 0-based start
  while s > 0 and is_tok(line:sub(s, s)) do s = s - 1 end
  if not is_tok(line:sub(s + 1, s + 1)) then s = s + 1 end
  local e = col + 1 -- 1-based end (inclusive)
  while e < #line and is_tok(line:sub(e + 1, e + 1)) do e = e + 1 end
  local token = line:sub(s + 1, e)
  if not is_tok(token) or token == "" then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  local stringcase = require("textcase.conversions.stringcase")
  local cases = {
    { label = "snake_case", fn = stringcase.to_snake_case },
    { label = "camelCase",  fn = stringcase.to_camel_case },
    { label = "PascalCase", fn = stringcase.to_pascal_case },
    { label = "UPPER_CASE", fn = stringcase.to_constant_case },
    { label = "kebab-case", fn = stringcase.to_dash_case },
  }
  vim.ui.select(cases, {
    prompt = "Convert case:",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice or not vim.api.nvim_win_is_valid(win) then return end
    local converted = choice.fn(token)
    -- Replace [s, e) on the original line; col args are 0-based, end exclusive.
    vim.api.nvim_buf_set_text(0, row, s, row, e, { converted })
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
