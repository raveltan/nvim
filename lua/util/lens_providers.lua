-- Custom lensline providers for PHP + Ruby workflows. Display-only.

local M = {}

-- ─── Authorization gate (Pundit / CanCanCan / Laravel Gate) ─────────────────
M.auth_gate = {
  name = "auth_gate",
  event = { "BufEnter", "BufWritePost" },
  handler = function(bufnr, fi, _, cb)
    if not (fi and fi.line and fi.end_line) then return end
    local body = vim.api.nvim_buf_get_lines(bufnr, fi.line - 1, fi.end_line, false)
    for _, l in ipairs(body) do
      if l:match("^%s*authorize[%s!(]")
          or l:match("^%s*authorize_resource")
          or l:match("Gate::")
          or l:match("$this%->authorize%(")
          or l:match("%->authorize%(") then
        cb({ line = fi.line, text = "🔒 authorized" })
        return
      end
    end
  end,
}

-- ─── Logger count ───────────────────────────────────────────────────────────
M.logger_count = {
  name = "logger_count",
  event = { "BufEnter", "BufWritePost" },
  handler = function(bufnr, fi, _, cb)
    if not (fi and fi.line and fi.end_line) then return end
    local body = vim.api.nvim_buf_get_lines(bufnr, fi.line - 1, fi.end_line, false)
    local n = 0
    for _, l in ipairs(body) do
      if l:match("Rails%.logger") or l:match("logger%.[%w_]+%(")
          or l:match("Log::[%w_]+%(") or l:match("Log%.[%w_]+%(")
          or l:match("%->logger%->") or l:match("error_log%(")
          or l:match("logger%->[%w_]+%(") or l:match("LoggerInterface") then
        n = n + 1
      end
    end
    if n > 0 then cb({ line = fi.line, text = ("log×%d"):format(n) }) end
  end,
}

return M
