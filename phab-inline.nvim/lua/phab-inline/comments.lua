-- Fetches and displays non-inline (general) revision comments in a floating
-- window. Uses the bundled scripts/phab-comments.sh script and shares the
-- PHID-resolution logic in fetch.lua.

local config   = require("phab-inline.config")
local revision = require("phab-inline.revision")
local fetch    = require("phab-inline.fetch")

local M = {}

-- cache[rev]    = { items = { transaction, ... } }  (oldest-first, pre-resolved)
-- inflight[rev] = true while a fetch is in progress
local cache    = {}
local inflight = {}

local function do_fetch(rev, cb)
  if inflight[rev] then return end
  inflight[rev] = true

  vim.system(
    { config.get().comments_script, rev, "--raw" },
    { text = true },
    function(o)
      if o.code ~= 0 then
        inflight[rev] = nil
        vim.schedule(function()
          vim.notify(
            "phab-inline: fetch comments failed for " .. rev .. ": " .. (o.stderr or ""),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, o.stdout or "")
      local items = (ok and type(decoded) == "table") and decoded or {}
      fetch.resolve_authors(items, function(authors)
        for _, c in ipairs(items) do
          c._author = authors[c.authorPHID] or c.authorPHID or "phab"
        end
        cache[rev] = { items = items }
        inflight[rev] = nil
        vim.schedule(function() if cb then cb(items) end end)
      end)
    end
  )
end

-- Build the display lines and highlight specs for the float.
-- Returns (lines, hls) where hls = list of { row (0-based), hl_group }.
-- Exported so tests can exercise it directly.
function M.build_view(rev, items)
  local lines = {}
  local hls   = {}
  local function add(line, hl)
    table.insert(lines, line)
    if hl then table.insert(hls, { #lines - 1, hl }) end
  end

  add(rev .. " - " .. #items .. " comment(s)", "Title")
  add("", nil)

  if #items == 0 then
    add("(no general comments)", "Comment")
    return lines, hls
  end

  for i, c in ipairs(items) do
    local author = c._author or c.authorPHID or "phab"
    local date   = ""
    if c.dateCreated then
      date = os.date("!%Y-%m-%d %H:%M UTC", tonumber(c.dateCreated)) or ""
    end
    local header = ("## %s  -  %s"):format(author, date)
    add(header, "DiagnosticHint")
    add(string.rep("-", math.max(8, #header)), "NonText")

    local body = ""
    if c.comments and c.comments[1] and c.comments[1].content then
      body = c.comments[1].content.raw or ""
    end
    for bline in (body .. "\n"):gmatch("([^\n]*)\n") do
      add(bline, nil)
    end
    if i < #items then add("", nil) end
  end

  return lines, hls
end

local function open_float(rev, items)
  local lines, hls = M.build_view(rev, items)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden  = "wipe"
  vim.bo[buf].filetype   = "markdown"
  pcall(vim.api.nvim_buf_set_name, buf, "phab://" .. rev .. "/comments")

  local view_ns = vim.api.nvim_create_namespace("phab_inline_comments_view")
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, view_ns, h[1], 0, {
      end_row  = h[1] + 1,
      hl_group = h[2],
      hl_eol   = true,
    })
  end

  local ui     = vim.api.nvim_list_uis()[1] or { width = 100, height = 30 }
  local width  = math.min(100, math.max(60, math.floor(ui.width  * 0.7)))
  local height = math.min(#lines + 2, math.max(10, math.floor(ui.height * 0.7)))
  local row    = math.floor((ui.height - height) / 2)
  local col    = math.floor((ui.width  - width)  / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. rev .. " comments ",
    title_pos = "center",
  })
  vim.wo[win].wrap       = true
  vim.wo[win].linebreak  = true
  vim.wo[win].cursorline = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q",     close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })
end

-- Show non-inline revision comments in a floating window.
-- opts.buf:     buffer used to derive the revision (default: current buffer)
-- opts.refresh: if true, bust the cache and refetch before opening
function M.show(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local rev = revision.find(revision.context_path(buf))
  if not rev then
    vim.notify("phab-inline: not in a D<id> worktree", vim.log.levels.INFO)
    return
  end

  if opts.refresh then cache[rev] = nil end

  if cache[rev] then
    open_float(rev, cache[rev].items)
    return
  end

  vim.notify("phab-inline: fetching comments for " .. rev .. "...", vim.log.levels.INFO)
  do_fetch(rev, function(items)
    open_float(rev, items)
  end)
end

-- Test hook: wipe all module-local state.
function M._reset()
  cache    = {}
  inflight = {}
end

return M
