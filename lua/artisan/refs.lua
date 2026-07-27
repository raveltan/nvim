-- `gf` resolvers for the two Laravel references neither plugin handles here.
--
--   route('posts.show')  — blade-nav shells out `artisan route:list --columns=…`,
--                          an option Laravel 13 removed, so it resolves nothing;
--                          laravel.nvim's own gf reports cursorOnResource=false
--                          in blade buffers.
--   __('posts.empty')    — blade-nav looks in `resources/lang`, but Laravel 9+
--                          moved translations to `lang/` at the project root.
--
-- Both jump to the definition AND position the cursor on it, which is the part
-- that makes `gf` worth pressing over a grep.
local M = {}

--- Cursor inside a quoted string that follows one of `patterns`? Returns the
--- string's contents.
---@param patterns string[] Lua patterns, each with one capture for the argument
---@return string|nil
local function arg_at_cursor(patterns)
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  for _, pattern in ipairs(patterns) do
    local init = 1
    while true do
      local s, e, captured = line:find(pattern, init)
      if not s then break end
      if col >= s and col <= e then return captured end
      init = e + 1
    end
  end
  return nil
end

--- Open `path` and put the cursor on the first line matching `pattern`.
local function open_at(path, pattern)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if not pattern then return true end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:find(pattern) then
      vim.api.nvim_win_set_cursor(0, { i, (line:find(pattern)) - 1 })
      vim.cmd("normal! zz")
      return true
    end
  end
  return true
end

--- route('posts.show') / route("posts.show")
---@return boolean handled
function M.route()
  local name = arg_at_cursor({
    "route%(%s*'([^']+)'",
    'route%(%s*"([^"]+)"',
  })
  if not name then return false end

  local root = require("artisan").root()
  if not root then return false end

  local needle = "%->name%(%s*['\"]" .. vim.pesc(name) .. "['\"]"
  for path, kind in vim.fs.dir(root .. "/routes", { depth = 4 }) do
    if kind == "file" and path:match("%.php$") then
      local full = root .. "/routes/" .. path
      for _, line in ipairs(vim.fn.readfile(full)) do
        if line:find(needle) then
          return open_at(full, needle)
        end
      end
    end
  end

  -- Implicit names from Route::resource/apiResource are never written out, so
  -- there is nothing to jump to. Say so rather than falling through to a
  -- confusing plain-gf failure.
  vim.notify(("No `->name('%s')` in routes/ (implicit resource route?)"):format(name), vim.log.levels.WARN)
  return true
end

--- __('posts.empty'), @lang('…'), trans('…'), trans_choice('…')
---@return boolean handled
function M.lang()
  local key = arg_at_cursor({
    "__%(%s*'([^']+)'",
    '__%(%s*"([^"]+)"',
    "@lang%(%s*'([^']+)'",
    "trans%w*%(%s*'([^']+)'",
    'trans%w*%(%s*"([^"]+)"',
  })
  if not key then return false end

  local root = require("artisan").root()
  if not root then return false end
  local lang_dir = root .. "/lang"
  if not vim.uv.fs_stat(lang_dir) then
    -- Pre-Laravel-9 layout.
    lang_dir = root .. "/resources/lang"
    if not vim.uv.fs_stat(lang_dir) then return false end
  end

  -- Locale directories first (`lang/en/posts.php`), then JSON catalogues
  -- (`lang/en.json`), which is where non-dotted keys live.
  local file, rest = key:match("^([^%.]+)%.(.+)$")
  if file then
    for entry, kind in vim.fs.dir(lang_dir) do
      if kind == "directory" then
        local candidate = ("%s/%s/%s.php"):format(lang_dir, entry, file:gsub("%.", "/"))
        if vim.uv.fs_stat(candidate) then
          local leaf = rest:match("([^%.]+)$")
          return open_at(candidate, "['\"]" .. vim.pesc(leaf) .. "['\"]%s*=>")
        end
      end
    end
  end

  for entry, kind in vim.fs.dir(lang_dir) do
    if kind == "file" and entry:match("%.json$") then
      local candidate = lang_dir .. "/" .. entry
      for _, line in ipairs(vim.fn.readfile(candidate)) do
        if line:find('"' .. vim.pesc(key) .. '"', 1, false) then
          return open_at(candidate, '"' .. vim.pesc(key) .. '"')
        end
      end
    end
  end

  vim.notify(("No translation for '%s' under %s"):format(key, vim.fn.fnamemodify(lang_dir, ":.")), vim.log.levels.WARN)
  return true
end

return M
