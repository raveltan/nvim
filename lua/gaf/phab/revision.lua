-- Working out which Differential revision a buffer belongs to, and which
-- directory its comment paths are relative to.
--
-- Sources, in order:
--   1. an explicit id the user set for this root (:PhabRevision / the prompt)
--   2. a D<digits> ancestor directory (the arc-patch worktree layout)
--   3. the `Differential Revision:` trailer of HEAD itself
--   4. an `arcpatch-D<id>` branch name
--   5. the same trailer anywhere in the last 50 commits
--   6. asking, when the caller allows it (interactive commands only)
--
-- HEAD's own trailer outranks the branch name because a patched stack keeps
-- the branch of the revision it started from: `arc patch` of D229985 on top of
-- D229984 leaves the branch called arcpatch-D229984 while HEAD is D229985's
-- commit. The tip is what the worktree actually shows, so it wins.
--
-- Everything but (1) and (5) is cached per repo root, so the git calls run once
-- per root per session rather than on every BufEnter.

local util = require("gaf.phab.util")

local M = {}

-- resolved[root] = "D123" | false (looked, found nothing)
local resolved = {}
-- roots[dir] = "<toplevel>" | false; keeps `git rev-parse` off the BufEnter path
-- after the first buffer of a directory.
local roots = {}
-- overrides[root] = "D123" set by the user; wins over detection.
local overrides = {}
-- asked[root] = true once the prompt has been shown for a root. Declining is
-- remembered too, so entering more buffers of that repo does not re-ask.
local asked = {}

-- ── path helpers ───────────────────────────────────────────────────────────

-- Walk up from `path` (file or directory) looking for a directory named
-- D<digits>. Returns (revision_id, that_directory) or nil.
function M.find(path)
  if not path or path == "" then return nil end
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  while dir and dir ~= "" and dir ~= "/" do
    local name = vim.fs.basename(dir)
    if name and name:match("^D%d+$") then return name, dir end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return nil
end

-- Best-effort "where am I?" for buffers without a file name (dashboard,
-- scratch buffers): the buffer name, else the window-local cwd, else the cwd.
function M.context_path(buf)
  local name = buf and vim.api.nvim_buf_get_name(buf) or ""
  if name ~= "" then return name end
  local ok, cwd = pcall(vim.fn.getcwd, 0)
  if ok and cwd and cwd ~= "" then return cwd end
  return vim.fn.getcwd()
end

-- Path of buf relative to `root`, or nil when it lives outside it.
function M.rel_path(buf, root)
  local full = vim.api.nvim_buf_get_name(buf)
  if full == "" then return nil end
  full = vim.fn.fnamemodify(full, ":p")
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if full:sub(1, #root + 1) ~= root .. "/" then return nil end
  return full:sub(#root + 2)
end

-- Accepts "D123", "123", or a Phabricator URL; returns "D123" or nil.
function M.normalize(input)
  if not input then return nil end
  local id = tostring(input):match("D(%d+)") or tostring(input):match("^%s*(%d+)%s*$")
  return id and ("D" .. id) or nil
end

-- ── git ────────────────────────────────────────────────────────────────────

-- Run git in `dir`, synchronously. These are cached by the callers, so the
-- cost is one call per repo root per session, not one per BufEnter.
local function git(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local ok, res = pcall(function()
    return vim.system(cmd, { text = true }):wait(2000)
  end)
  if not ok or not res or res.code ~= 0 then return nil end
  return (res.stdout or ""):gsub("%s+$", "")
end

-- Top level of the worktree containing `path` (a worktree of its own for
-- `git worktree` checkouts, which is what the arcpatch layout uses).
function M.git_root(path)
  if not path or path == "" then return nil end
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  if not dir or dir == "" then return nil end
  if roots[dir] == nil then
    local out = git(dir, { "rev-parse", "--show-toplevel" })
    roots[dir] = (out and out ~= "") and out or false
  end
  return roots[dir] or nil
end

-- The trailer of HEAD alone. This is the revision whose code the worktree is
-- showing, which the branch name can disagree with on a patched stack.
function M.from_head(root)
  local out = git(root, { "log", "-1", "--format=%B" })
  if not out then return nil end
  local id = out:match("Differential Revision:%s*%S-/D(%d+)")
  return id and ("D" .. id) or nil
end

-- `arcpatch-D229984` is what `arc patch` names the branch it creates.
function M.from_branch(root)
  local branch = git(root, { "rev-parse", "--abbrev-ref", "HEAD" })
  if not branch then return nil end
  local id = branch:match("^arcpatch%-D(%d+)$") or branch:match("^D(%d+)$")
  return id and ("D" .. id) or nil
end

-- The `Differential Revision: <url>/D229985` trailer arc writes when a
-- revision lands. Scans back a little: the tip is often a local fixup that has
-- not been amended into the revision commit yet.
function M.from_log(root, depth)
  local out = git(root, { "log", "-n", tostring(depth or 50), "--format=%B" })
  if not out then return nil end
  local id = out:match("Differential Revision:%s*%S-/D(%d+)")
  return id and ("D" .. id) or nil
end

-- ── resolution ─────────────────────────────────────────────────────────────

function M.set(root, rev)
  overrides[root] = rev
end

function M.forget(root)
  overrides[root] = nil
  resolved[root] = nil
  asked[root] = nil
end

function M.was_asked(root) return asked[root] == true end

-- Everything but the prompt. Returns (rev, root) with rev possibly nil.
function M.detect(buf)
  local path = M.context_path(buf or vim.api.nvim_get_current_buf())

  -- A D<id> directory names both the revision and the root its comment paths
  -- are relative to, so it is answered without touching git.
  local dir_rev, dir_root = M.find(path)
  if dir_rev then return dir_rev, dir_root end

  local root = M.git_root(path)
  if not root then return nil, nil end

  if overrides[root] then return overrides[root], root end
  if resolved[root] ~= nil then
    return resolved[root] or nil, root
  end

  local rev = M.from_head(root) or M.from_branch(root) or M.from_log(root)
  resolved[root] = rev or false
  return rev, root
end

-- Resolve to (rev, root) and hand them to cb. When detection comes up empty
-- and opts.prompt is set, ask for the id and remember the answer for this
-- root; without opts.prompt, notify and never call cb.
--
-- opts.rev forces an id (a command argument), also remembered for the root.
-- opts.prompt_once only prompts if this root has never been asked before (the
-- automatic path: ask when a repo is first opened, never nag afterwards).
---@param opts { buf?: number, prompt?: boolean, prompt_once?: boolean, rev?: string }
---@param cb fun(rev: string, root: string)
function M.resolve(opts, cb)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()

  local forced = M.normalize(opts.rev)
  local rev, root = M.detect(buf)
  root = root or M.git_root(M.context_path(buf))

  if forced then
    if not root then
      util.notify("not inside a git worktree — cannot resolve comment paths", vim.log.levels.WARN)
      return
    end
    M.set(root, forced)
    cb(forced, root)
    return
  end

  if rev and root then
    cb(rev, root)
    return
  end

  if not root then
    util.notify("not inside a git worktree", vim.log.levels.WARN)
    return
  end

  if opts.prompt_once and asked[root] then return end
  if not (opts.prompt or opts.prompt_once) then return end
  asked[root] = true

  vim.ui.input({ prompt = "Phabricator revision for " .. vim.fn.fnamemodify(root, ":t") .. " (D… or id, empty to skip): " }, function(input)
    local id = M.normalize(input)
    if not id then
      if input and input ~= "" then
        util.notify("not a revision id: " .. input, vim.log.levels.WARN)
      end
      return
    end
    M.set(root, id)
    cb(id, root)
  end)
end

-- Test hook: wipe the module-local caches.
function M._reset()
  resolved = {}
  overrides = {}
  roots = {}
  asked = {}
end

return M
