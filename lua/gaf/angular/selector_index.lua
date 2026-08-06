-- Repo-wide index of Angular ELEMENT selectors, feeding tag-name completion in
-- inline templates (`<fl-…`). Completing a tag can't work like the attribute
-- lookup does -- there is no tag under the cursor yet to rg for -- so the whole
-- repo is read once (one rg, ~0.5s over the 13k-file GAF webapp) and every later
-- keystroke is a table read. A `.ts` write patches that one file's entries
-- rather than rebuilding.
--
-- `rg_run` is injected by lua/gaf/angular/init.lua instead of required back out of
-- it, so the rg invocation (type filters, async plumbing) lives in one place.
local M = {}

-- root -> selector -> { { file, lnum }, ... }. A selector legitimately has
-- several definitions (the webapp defines `app-search` in three places), and the
-- table is per root because the user moves between git worktrees -- two roots
-- can be live in one session.
local index = {}

-- root -> callbacks waiting on the in-flight build. Without this, the N
-- keystrokes typed while the first rg runs would each spawn their own.
local pending = {}

-- root -> counter bumped on every change. Turning the index into completion
-- items costs ~30ms over the webapp (a dir label per definition, then a sort),
-- far too much to repeat per keystroke; a consumer memoizes that derived list
-- and compares this instead. update_file patches entry tables in place, so
-- identity can't carry the signal.
local revision = {}

function M.revision(root)
  return revision[root] or 0
end

local function bump(root)
  revision[root] = (revision[root] or 0) + 1
end

-- rg's own pattern for a `selector:` definition, and the Lua pattern that reads
-- the value back out of the matched line.
local RG_SELECTOR = "selector:\\s*['\"][^'\"]+['\"]"
local LUA_SELECTOR = "selector:%s*['\"]([^'\"]+)['\"]"

-- Element selectors within one raw `selector:` value. Angular allows a comma
-- list mixing forms (`'fl-a, [flA], .fl-a'`); only a dashed bare name can be
-- typed as a tag, so `[attr]`, `.class`, `:not(…)` and native tags are dropped.
local function element_selectors(raw)
  local out = {}
  for piece in raw:gmatch("[^,]+") do
    local sel = vim.trim(piece)
    if sel:find("%-") and sel:match("^[%w][%w%-]*$") then
      out[#out + 1] = sel
    end
  end
  return out
end

local function add(idx, sel, file, lnum)
  local entries = idx[sel]
  if not entries then
    entries = {}
    idx[sel] = entries
  end
  entries[#entries + 1] = { file = file, lnum = lnum }
end

-- One rg over `root` -> a fresh index handed to `cb`. Always rebuilds; callers
-- that want the cached one use M.get.
function M.build(root, rg_run, cb)
  rg_run({ RG_SELECTOR }, { root }, function(items)
    local idx = {}
    for _, it in ipairs(items) do
      local raw = (it.line or ""):match(LUA_SELECTOR)
      if raw then
        for _, sel in ipairs(element_selectors(raw)) do
          add(idx, sel, it.file, it.pos[1])
        end
      end
    end
    cb(idx)
  end)
end

-- Cached accessor: synchronous `cb` when the root is already indexed, otherwise
-- one build that every concurrent caller waits on.
function M.get(root, rg_run, cb)
  local idx = index[root]
  if idx then return cb(idx) end
  local queue = pending[root]
  if queue then
    queue[#queue + 1] = cb
    return
  end
  pending[root] = { cb }
  M.build(root, rg_run, function(built)
    index[root] = built
    bump(root)
    local queued = pending[root] or {}
    pending[root] = nil
    for _, f in ipairs(queued) do
      f(built)
    end
  end)
end

function M.invalidate(root)
  index[root] = nil
end

-- Re-read one file's selectors after a write and patch them in. A line scan is
-- enough here (no treesitter, no rg), so this is cheap enough for every `.ts`
-- save. Never builds: an unindexed root stays unindexed until completion asks
-- for it, and files outside the root (or spec files, which the index excludes)
-- are ignored so a stray write can't smuggle entries in.
function M.update_file(root, file)
  local idx = index[root]
  if not idx then return end
  if file:sub(1, #root) ~= root or file:match("%.spec%.ts$") then return end

  local changed = false
  for sel, entries in pairs(idx) do
    for i = #entries, 1, -1 do
      if entries[i].file == file then
        table.remove(entries, i)
        changed = true
      end
    end
    if #entries == 0 then idx[sel] = nil end
  end

  local ok, lines = pcall(vim.fn.readfile, file)
  if ok then
    for lnum, line in ipairs(lines) do
      local raw = line:match(LUA_SELECTOR)
      if raw then
        for _, sel in ipairs(element_selectors(raw)) do
          add(idx, sel, file, lnum)
          changed = true
        end
      end
    end
  end
  -- Most saved `.ts` files declare no selector at all; leaving the revision
  -- alone then keeps the derived completion list valid across those saves.
  if changed then bump(root) end
end

return M
