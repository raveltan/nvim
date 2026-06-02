local map = vim.keymap.set

-- Granular undo: break the insert-undo so one `u` doesn't wipe a whole insert
-- session. C-w/C-u become separately undoable; sentence punctuation splits a
-- paragraph into per-sentence undo steps. (Tradeoff: `.` dot-repeat only
-- replays the last chunk after a break.)
map("i", "<C-w>", "<C-g>u<C-w>", { desc = "Delete word (undo break)" })
map("i", "<C-u>", "<C-g>u<C-u>", { desc = "Delete to BOL (undo break)" })
for _, ch in ipairs({ ".", ",", ";", "!", "?" }) do
  map("i", ch, ch .. "<C-g>u")
end

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

-- Case conversion via vim-abolish (operates on word under cursor)
map("n", "<leader>cvs", "crsiw", { remap = true, desc = "snake_case" })
map("n", "<leader>cvc", "crciw", { remap = true, desc = "camelCase" })
map("n", "<leader>cvp", "crmiw", { remap = true, desc = "PascalCase" })
map("n", "<leader>cvu", "cruiw", { remap = true, desc = "UPPER_CASE" })
map("n", "<leader>cvk", "cr-iw", { remap = true, desc = "kebab-case" })
map("n", "<leader>cvd", "cr.iw", { remap = true, desc = "dot.case" })
map("n", "<leader>cvt", "crtiw", { remap = true, desc = "Title Case" })

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
map("n", "<C-d>", "15jzz", { desc = "Small jump down (centered)" })
map("n", "<C-u>", "15kzz", { desc = "Small jump up (centered)" })
map("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Next search result (centered)" })
map("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>zzzv]], { desc = "Prev search result (centered)" })

-- ]] / [[ — jump to next/prev occurrence of the word under cursor via plain
-- text search (no LSP). Sets the search register (whole-word, \V so symbols
-- stay literal) + hlsearch, then feeds n/N so the centered+hlslens maps above
-- fire and `n`/`N` keep cycling afterwards.
local function search_cword(next_key)
  local w = vim.fn.expand("<cword>")
  if w == "" then return end
  vim.fn.setreg("/", [[\V\<]] .. vim.fn.escape(w, [[\]]) .. [[\>]])
  vim.opt.hlsearch = true
  vim.api.nvim_feedkeys(next_key, "m", false)
end
map("n", "]]", function() search_cword("n") end, { desc = "Next occurrence of word (text search)" })
map("n", "[[", function() search_cword("N") end, { desc = "Prev occurrence of word (text search)" })

-- Join without moving cursor
map("n", "J", "mzJ`z", { desc = "Join lines" })

-- Folding (native treesitter foldexpr). za/zR/zM/zr/zm are built-ins; zx
-- recomputes folds after foldexpr leaves stale boundaries (neovim#26224).
map("n", "<leader>zx", "zx", { desc = "Recompute folds" })

map("n", "gx", function()
  if vim.g.gaf and require("gaf.keymaps").open_phab_under_cursor() then return end
  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then vim.ui.open(cfile) end
end, { desc = "Open URL/file under cursor" })

-- Chrome DevTools (webconnect bridge) — <leader>j = chrome devtools group
local wc = function() return require("util.webconsole") end
local wn = function() return require("util.webnetwork") end
local ws = function() return require("util.webstorage") end
local wd = function() return require("util.webdom") end
local wem = function() return require("util.webemulate") end
local wcl = function() return require("util.webclient") end
local wh = function() return require("util.webhelp") end

map("n", "<leader>jl", function() wcl().launch_connect() end, { desc = "Launch debug Chrome + connect (no panel)" })
map("n", "<leader>jc", function() wc().toggle() end, { desc = "Toggle console" })
map("n", "<leader>je", function() wc().eval_line() end, { desc = "Eval current line" })
map("v", "<leader>je", function() wc().eval_visual() end, { desc = "Eval selection" })
map("n", "<leader>jp", function() wc().eval_prompt() end, { desc = "Eval prompt (JS>)" })
map("n", "<leader>jg", function() wc().navigate() end, { desc = "Navigate to URL" })
map("n", "<leader>jx", function() wc().clear() end, { desc = "Clear console" })
map("n", "<leader>jr", function() wc().reload() end, { desc = "Reload page" })
map("n", "<leader>jn", function() wn().toggle() end, { desc = "Toggle network panel" })
map("n", "<leader>js", function() ws().toggle() end, { desc = "Toggle storage panel" })
map("n", "<leader>ji", function() wd().toggle() end, { desc = "Elements panel (DOM tree)" })
map("n", "<leader>jI", function() wd().inspect() end, { desc = "Inspect DOM (selector)" })
map("n", "<leader>jt", function() wcl().pick_tab() end, { desc = "Pick Chrome tab to attach" })
map("n", "<leader>jq", function() wc().stop() end, { desc = "Disconnect" })
map("n", "<leader>jk", function() wcl().kill_port() end, { desc = "Kill stale debug port" })
map("n", "<leader>jP", function() wcl().screenshot(false) end, { desc = "Screenshot (viewport)" })
map("n", "<leader>j?", function() wh().show() end, { desc = "DevTools help" })

-- Emulation subgroup: <leader>jd…
map("n", "<leader>jdd", function() wem().device() end, { desc = "Emulate device (responsive)" })
map("n", "<leader>jdu", function() wem().user_agent() end, { desc = "Override user agent" })
map("n", "<leader>jdw", function() wem().throttle() end, { desc = "Throttle network/CPU" })
map("n", "<leader>jdr", function() wem().reset_all() end, { desc = "Reset all emulation" })
map("n", "<leader>jdo", function() wem().rotate() end, { desc = "Rotate orientation" })

vim.api.nvim_create_user_command("ChromeLaunch", function(o)
  wcl().launch_connect({ fresh = o.bang, url = o.args ~= "" and o.args or nil })
end, { bang = true, nargs = "?", desc = "Launch debug Chrome (! = fresh profile copy) and connect (no panel)" })
vim.api.nvim_create_user_command("ChromeConsole", function() wc().toggle() end, { desc = "Toggle Chrome console" })
vim.api.nvim_create_user_command("ChromeConsoleStop", function() wc().stop() end, { desc = "Disconnect Chrome console" })
vim.api.nvim_create_user_command("ChromeConsoleBuild", function() wc().build() end, { desc = "Build the webconnect Go binary" })
vim.api.nvim_create_user_command("ChromeEval", function(o) wc().eval(o.args) end, { nargs = "+", desc = "Eval JS in Chrome" })
vim.api.nvim_create_user_command("ChromeNetwork", function() wn().toggle() end, { desc = "Toggle Chrome network panel" })
vim.api.nvim_create_user_command("ChromeNetworkStop", function() wn().stop() end, { desc = "Close Chrome network panel" })
vim.api.nvim_create_user_command("ChromeStorage", function() ws().toggle() end, { desc = "Toggle Chrome storage panel" })
vim.api.nvim_create_user_command("ChromeStorageStop", function() ws().stop() end, { desc = "Close Chrome storage panel" })
vim.api.nvim_create_user_command("ChromeTabs", function() wcl().pick_tab() end, { desc = "Pick a Chrome tab to attach to" })
vim.api.nvim_create_user_command("ChromeDevice", function() wem().device() end, { desc = "Emulate a device (responsive)" })
vim.api.nvim_create_user_command("ChromeUserAgent", function() wem().user_agent() end, { desc = "Override user agent" })
vim.api.nvim_create_user_command("ChromeThrottle", function() wem().throttle() end, { desc = "Throttle network / CPU" })
vim.api.nvim_create_user_command("ChromeKill", function() wcl().kill_port() end, { desc = "Kill process holding the debug port" })
vim.api.nvim_create_user_command("ChromeRelaunch", function(o)
  wcl().kill_port(function() wcl().launch_connect({ fresh = o.bang }) end)
end, { bang = true, desc = "Kill stale port then launch fresh (! = fresh profile)" })
vim.api.nvim_create_user_command("ChromeReload", function() wc().reload() end, { desc = "Reload the attached Chrome tab" })
vim.api.nvim_create_user_command("ChromeNavigate", function(o) wc().navigate(o.args) end, { nargs = 1, desc = "Navigate the attached Chrome tab" })
vim.api.nvim_create_user_command("ChromeShot", function(o) wcl().screenshot(o.bang) end, { bang = true, desc = "Screenshot the tab (! = full page)" })
vim.api.nvim_create_user_command("ChromeInspect", function() wd().inspect() end, { desc = "Inspect a DOM element by selector" })
vim.api.nvim_create_user_command("ChromeDom", function() wd().toggle() end, { desc = "Toggle Chrome DOM inspect panel" })
vim.api.nvim_create_user_command("ChromeClear", function() wc().clear() end, { desc = "Clear the Chrome console" })
vim.api.nvim_create_user_command("ChromeEmulateReset", function() wem().reset_all() end, { desc = "Reset all Chrome emulation overrides" })
