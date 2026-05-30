-- webhelp — a global cheat-sheet float for the Chrome DevTools bridge.
-- Shows live connection/emulation status plus the full <leader>j… scheme and
-- the per-panel in-panel keys. Defensive: every module is required via pcall so
-- a missing/broken module never breaks the help screen.

local M = {}

-- safe require: returns the module or nil (never errors).
local function safe(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  end
  return nil
end

-- best-effort call: returns the result or a fallback on any error.
local function try(fn, fallback)
  if type(fn) ~= "function" then
    return fallback
  end
  local ok, res = pcall(fn)
  if ok then
    return res
  end
  return fallback
end

-- build the status line(s) at the top of the float.
local function status_lines()
  local lines = {}
  local client = safe("util.webclient")
  local status = "off"
  local title = ""
  if client then
    status = try(client.status, "off") or "off"
    local att = try(client.attached, {}) or {}
    title = att.title or ""
  end
  if status == "off" then
    lines[#lines + 1] = "Status: off"
  elseif title ~= "" then
    lines[#lines + 1] = ("Status: %s  ·  Tab: %s"):format(status, title)
  else
    lines[#lines + 1] = ("Status: %s"):format(status)
  end

  local emulate = safe("util.webemulate")
  if emulate then
    local emu = try(emulate.status, "") or ""
    if emu ~= "" then
      lines[#lines + 1] = "Emulating: " .. emu
    end
  end
  return lines
end

-- the static cheat-sheet body.
local function body_lines()
  return {
    "",
    "── Global <leader>j ──────────────────────────────",
    "  jl  launch + connect (no panel) jc  toggle console",
    "  je  eval line (v: selection)   jp  eval prompt",
    "  jg  navigate to URL            jx  clear console",
    "  jr  reload page                jn  network panel",
    "  js  storage panel              ji  Elements panel",
    "  jI  inspect DOM (selector)",
    "  jt  pick tab                   jq  disconnect",
    "  jk  kill stale port            jP  screenshot",
    "  j?  this help",
    "  Emulate  jdd device · jdu user-agent · jdw throttle",
    "           jdr reset-all · jdo rotate",
    "",
    "── Console panel ─────────────────────────────────",
    "  <CR>/<Tab> expand · Y yank value · ? help",
    "  input: <CR> eval · <C-p>/<C-n> history",
    "         <C-Space> JS autocomplete",
    "",
    "── Network panel ─────────────────────────────────",
    "  / filter · F status filter · 1-0 type filters",
    "  <CR> select · gd detail · yy URL · yc curl",
    "  yr response · yp payload · b/B block · H HAR",
    "  E expand-all · X clear · ? help · q close",
    "",
    "── Storage panel ─────────────────────────────────",
    "  <CR> expand/yank · e edit · d delete · a add",
    "  C clear · R refresh · / filter · yk yank key",
    "  ? help · q close",
    "",
    "── Elements panel (DOM) ──────────────────────────",
    "  <CR>/<Tab> expand/collapse · c edit class",
    "  A add/edit attr · d remove attr · e edit HTML",
    "  r refresh · i inspect (selector) · ? help · q close",
    "",
    "Panels auto-clear/refetch on page navigation.",
    "Press q or <Esc> to close.",
  }
end

function M.show()
  local lines = status_lines()
  for _, l in ipairs(body_lines()) do
    lines[#lines + 1] = l
  end

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = width + 2
  local height = #lines

  local ui = vim.api.nvim_list_uis()[1]
  local cols = (ui and ui.width) or vim.o.columns
  local rows = (ui and ui.height) or vim.o.lines
  width = math.min(width, cols - 4)
  height = math.min(height, rows - 4)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "webhelp"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Chrome DevTools ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
end

return M
