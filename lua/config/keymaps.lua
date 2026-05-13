local map = vim.keymap.set

-- Window splits
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Save / Quit
map({ "n", "i", "x", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Buffer
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<cr>", { desc = "Close other buffers" })

-- Window resize
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Window resize submode: press <leader>wr, then h/j/k/l (shift = bigger step), = to equalize, Esc/q to exit
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
map("n", "<leader>wr", resize_submode, { desc = "Resize submode (hjkl)" })

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

  vim.ui.input({ prompt = "Rename: ", default = cword }, function(new_name)
    if not new_name or new_name == "" or new_name == cword then return end
    params.newName = new_name
    client:request("textDocument/rename", params, function(err, result)
      if err then
        vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
        return
      end
      if not result then
        vim.notify("Language server returned no rename result", vim.log.levels.WARN)
        return
      end
      vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
    end, bufnr)
  end)
end, { desc = "Rename symbol" })
map("n", "<leader>cf", function() require("conform").format({ async = true }) end, { desc = "Format file" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR }) end, { desc = "Prev error" })
map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next error" })
map("n", "[w", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN }) end, { desc = "Prev warning" })
map("n", "]w", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN }) end, { desc = "Next warning" })

-- Inlay hints toggle
map("n", "<leader>ci", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-- Toggle diagnostics
map("n", "<leader>ud", function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Toggle diagnostics" })

-- Toggle format-on-save
map("n", "<leader>uf", function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify(vim.g.disable_autoformat and "Format-on-save disabled" or "Format-on-save enabled")
end, { desc = "Toggle format-on-save" })

-- Better indentation (keep selection)
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Paste without overwriting register
map("x", "<leader>p", [["_dP]], { desc = "Paste without overwrite" })

-- New file
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })

-- Quickfix / Location list
map("n", "<leader>xq", function()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 and win.loclist == 0 then
      vim.cmd.cclose()
      return
    end
  end
  vim.cmd.copen()
end, { desc = "Toggle quickfix" })
map("n", "<leader>xl", function()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.loclist == 1 then
      vim.cmd.lclose()
      return
    end
  end
  pcall(vim.cmd.lopen)
end, { desc = "Toggle loclist" })

-- Grep word under cursor
map("n", "gw", function()
  Snacks.picker.grep({ search = vim.fn.expand("<cword>") })
end, { desc = "Grep word under cursor" })

-- Center after jumps
map("n", "<C-d>", "10jzz", { desc = "Small jump down (centered)" })
map("n", "<C-u>", "10kzz", { desc = "Small jump up (centered)" })
map("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Next search result (centered)" })
map("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Prev search result (centered)" })

-- Join without moving cursor
map("n", "J", "mzJ`z", { desc = "Join lines" })

-- Phabricator object opener: gx on D12345 / T12345 opens the Phab URL
local function open_phab_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local init = 1
  while init <= #line do
    local s, e, token = line:find("([DT]%d+)", init)
    if not s then break end
    if col >= s and col <= e then
      vim.ui.open("https://phabricator.tools.flnltd.com/" .. token)
      return true
    end
    init = e + 1
  end
  return false
end

map("n", "gx", function()
  if open_phab_under_cursor() then return end
  local cword = vim.fn.expand("<cword>")
  if cword:match("^[DT]%d+$") then
    vim.ui.open("https://phabricator.tools.flnltd.com/" .. cword)
    return
  end
  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then vim.ui.open(cfile) end
end, { desc = "Open URL/file/Phab object under cursor" })
