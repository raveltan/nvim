local M = {}

-- gx on D12345 / T12345 tokens opens the Phabricator URL.
function M.open_phab_under_cursor()
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
  local cword = vim.fn.expand("<cword>")
  if cword:match("^[DT]%d+$") then
    vim.ui.open("https://phabricator.tools.flnltd.com/" .. cword)
    return true
  end
  return false
end

function M.setup()
end

return M
