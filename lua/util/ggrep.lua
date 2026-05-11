local M = {}

local function run(pattern, extra_args)
  if not pattern or pattern == "" then return end
  local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  if not root or root == "" or vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repo", vim.log.levels.WARN)
    return
  end

  local cmd = { "git", "-C", root, "grep", "-n", "--column", "-I", "--no-color" }
  for _, a in ipairs(extra_args or {}) do table.insert(cmd, a) end
  table.insert(cmd, "--")
  table.insert(cmd, pattern)

  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 and #lines == 0 then
    vim.notify("No matches for: " .. pattern, vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, line in ipairs(lines) do
    local file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
    if file then
      table.insert(items, {
        text = string.format("%s:%s:%s: %s", file, lnum, col, text),
        file = root .. "/" .. file,
        pos = { tonumber(lnum), tonumber(col) - 1 },
        line = text,
      })
    end
  end

  if #items == 0 then
    vim.notify("No matches for: " .. pattern, vim.log.levels.INFO)
    return
  end

  Snacks.picker.pick({
    source = "ggrep",
    title = "git grep: " .. pattern,
    items = items,
    format = "file",
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      vim.api.nvim_win_set_cursor(0, item.pos)
    end,
  })
end

function M.prompt()
  local pat = vim.fn.input("git grep: ")
  run(pat)
end

function M.cword()
  run(vim.fn.expand("<cword>"), { "-w" })
end

function M.visual()
  local save = vim.fn.getreg("v")
  vim.cmd('normal! "vy')
  local sel = vim.fn.getreg("v")
  vim.fn.setreg("v", save)
  run(sel, { "-F" })
end

return M
