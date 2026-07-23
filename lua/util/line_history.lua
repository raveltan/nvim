local M = {}

-- `git show <sha>` output is immutable, so cache it per sha+path. Combined with
-- the async fetch below this means scrolling back over a row is instant and
-- never re-spawns git.
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

-- Shared picker: runs `git log` with the given scope args, lists matching
-- commits, previews each via `git show` (async + cached), and on select opens
-- the commit read-only with `:Gedit <sha>` — never checks it out.
local function pick_commits(opts)
  local fmt = "%h\t%an\t%ar\t%s"
  local cmd = { "git", "log", "-n", "200", "--no-patch", "--pretty=format:" .. fmt }
  vim.list_extend(cmd, opts.log_args)

  -- Async: `git log -L` traces history with no early exit — synchronous
  -- systemlist froze nvim for seconds on old files. -n 200 bounds the worst case.
  vim.system(cmd, { text = true, cwd = opts.dir }, vim.schedule_wrap(function(res)
    local lines = vim.split(res.stdout or "", "\n", { trimempty = true })
    if res.code ~= 0 or #lines == 0 then
      vim.notify(opts.empty_msg, vim.log.levels.WARN)
      return
    end

    local items = {}
    for _, line in ipairs(lines) do
      local sha, author, when, subject = line:match("^(%S+)\t([^\t]*)\t([^\t]*)\t(.*)$")
      if sha then
        table.insert(items, {
          text = string.format("%s  %s  %s  %s", sha, when, author, subject),
          sha = sha,
        })
      end
    end

    Snacks.picker.pick({
      source = opts.source,
      title = opts.title,
      items = items,
      format = function(item) return { { item.text } } end,
      preview = function(ctx)
        local sha = ctx.item.sha
        local key = sha .. ":" .. opts.rel
        local function show(out)
          ctx.preview:reset()
          ctx.preview:set_lines(out)
          ctx.preview:highlight({ ft = "git" })
        end

        local cached = show_cache[key]
        if cached then
          show(cached)
          return
        end

        -- Async: never block the UI loop on `git show` while arrow-keying.
        preview_gen = preview_gen + 1
        local my_gen = preview_gen
        ctx.preview:reset()
        ctx.preview:set_lines({ "Loading " .. sha .. " …" })
        vim.system(
          { "git", "show", "--format=", "--stat", "-p", sha, "--", opts.path },
          { text = true, cwd = opts.dir },
          vim.schedule_wrap(function(show_res)
            local out = vim.split(show_res.stdout or "", "\n")
            if out[#out] == "" then out[#out] = nil end
            show_cache[key] = out
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
  end))
end

-- Commits touching a line range (default: current line), opened read-only.
function M.pick(s, e)
  s, e = get_range(s, e)
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file", vim.log.levels.WARN)
    return
  end
  local rel = vim.fn.fnamemodify(file, ":.")
  local dir = vim.fn.fnamemodify(file, ":h")
  local name = vim.fn.fnamemodify(file, ":t")
  pick_commits({
    source = "line_history",
    title = string.format("Line history %d-%d : %s", s, e, rel),
    -- git runs with cwd=dir, so pathspecs are the basename -- works for files
    -- outside nvim's cwd (e.g. a file in a different repo).
    log_args = { string.format("-L%d,%d:%s", s, e, name) },
    rel = rel,
    path = name,
    dir = dir,
    empty_msg = "No history for lines " .. s .. "-" .. e,
  })
end

-- Commits touching the whole current file (follows renames), opened read-only.
function M.file()
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file", vim.log.levels.WARN)
    return
  end
  local rel = vim.fn.fnamemodify(file, ":.")
  local dir = vim.fn.fnamemodify(file, ":h")
  local name = vim.fn.fnamemodify(file, ":t")
  pick_commits({
    source = "file_history",
    title = "File history : " .. rel,
    log_args = { "--follow", "--", name },
    rel = rel,
    path = name,
    dir = dir,
    empty_msg = "No history for " .. rel,
  })
end

return M
