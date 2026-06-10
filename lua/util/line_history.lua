local M = {}

-- `git show <sha>` output is immutable, so cache it per sha. Combined with the
-- async fetch below this means scrolling back over a row is instant and never
-- re-spawns git.
local show_cache = {}
-- Monotonic token: each preview request bumps it. A slow earlier `git show`
-- resolving after the selection moved on is dropped instead of clobbering the
-- newer preview.
local preview_gen = 0

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

  -- Async: `git log -L` traces the range through the file's entire history with
  -- no early exit — synchronous systemlist froze nvim for seconds on old files.
  -- -n 200 bounds the worst case; git stops once the count is reached.
  local fmt = "%h\t%an\t%ar\t%s"
  vim.system(
    { "git", "log", "-n", "200", range, "--no-patch", "--pretty=format:" .. fmt },
    { text = true },
    vim.schedule_wrap(function(res)
      local lines = vim.split(res.stdout or "", "\n", { trimempty = true })
      if res.code ~= 0 or #lines == 0 then
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
          local sha = ctx.item.sha
          local function show(out)
            ctx.preview:reset()
            ctx.preview:set_lines(out)
            ctx.preview:highlight({ ft = "git" })
          end

          local cached = show_cache[sha]
          if cached then
            show(cached)
            return
          end

          -- Async: never block the UI loop on `git show` while arrow-keying through
          -- the list (the old synchronous systemlist froze nvim on every cursor
          -- move, made worse on a large repo).
          preview_gen = preview_gen + 1
          local my_gen = preview_gen
          ctx.preview:reset()
          ctx.preview:set_lines({ "Loading " .. sha .. " …" })
          vim.system(
            { "git", "show", "--stat", "-p", sha, "--", rel },
            { text = true },
            vim.schedule_wrap(function(show_res)
              local out = vim.split(show_res.stdout or "", "\n")
              if out[#out] == "" then out[#out] = nil end
              show_cache[sha] = out
              -- Selection moved on while git ran; the current preview is newer.
              if my_gen ~= preview_gen then return end
              pcall(show, out)
            end)
          )
        end,
        confirm = function(picker, item)
          picker:close()
          vim.cmd("Gedit " .. item.sha)
        end,
      })
    end)
  )
end

return M
