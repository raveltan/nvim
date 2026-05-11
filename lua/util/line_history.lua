local M = {}

local function get_range(s, e)
  if s and e then return s, e end
  local l = vim.fn.line(".")
  return l, l
end

function M.pick(s, e)
  s, e = get_range(s, e)
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file", vim.log.levels.WARN)
    return
  end
  local rel = vim.fn.fnamemodify(file, ":.")
  local range = string.format("-L%d,%d:%s", s, e, rel)

  local fmt = "%h\t%an\t%ar\t%s"
  local lines = vim.fn.systemlist({
    "git", "log", range, "--no-patch", "--pretty=format:" .. fmt,
  })
  if vim.v.shell_error ~= 0 or #lines == 0 then
    vim.notify("No history for lines " .. s .. "-" .. e, vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, line in ipairs(lines) do
    local sha, author, when, subject = line:match("^(%S+)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if sha then
      table.insert(items, {
        text = string.format("%s  %s  %s  %s", sha, when, author, subject),
        sha = sha,
        author = author,
        when = when,
        subject = subject,
      })
    end
  end

  Snacks.picker.pick({
    source = "line_history",
    title = string.format("Line history %d-%d : %s", s, e, rel),
    items = items,
    format = function(item) return { { item.text } } end,
    preview = function(ctx)
      local out = vim.fn.systemlist({
        "git", "show", "--stat", "-p", ctx.item.sha, "--", rel,
      })
      ctx.preview:reset()
      ctx.preview:set_lines(out)
      ctx.preview:highlight({ ft = "git" })
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd("Gedit " .. item.sha)
    end,
  })
end

return M
