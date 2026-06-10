local M = {}

-- Live, streaming git grep via the built-in snacks source (async proc finder).
-- The old implementation ran `git grep` synchronously over the whole repo via
-- vim.fn.systemlist and materialized every match before opening the picker —
-- seconds of frozen UI on broad patterns in the GAF monorepo.
-- cmd_args are extra `git grep` flags, passed through snacks' git args support.
local function pick(search, cmd_args)
  if not Snacks.git.get_root() then
    vim.notify("Not in a git repo", vim.log.levels.WARN)
    return
  end
  Snacks.picker.git_grep({
    cmd_args = cmd_args,
    search = search or "",
  })
end

function M.prompt()
  pick() -- live: type in the picker input, results stream in per keystroke
end

function M.cword()
  pick(vim.fn.expand("<cword>"), { "-w" })
end

function M.visual()
  local save = vim.fn.getreg("v")
  vim.cmd('normal! "vy')
  local sel = vim.fn.getreg("v")
  vim.fn.setreg("v", save)
  pick(sel, { "-F" })
end

return M
