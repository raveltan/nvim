-- Pure path helpers for locating the D<id> worktree ancestor of a path,
-- guessing a sensible "where am I?" path for buffers without a name, and
-- computing a buffer's path relative to a worktree root.

local M = {}

-- Memoize results: the worktree ancestor of an absolute path never changes
-- within a session. The autocmd in commands.lua calls find() on every BufEnter
-- for every buffer (incl. files outside any D-worktree, where the walk runs all
-- the way to "/"); caching turns that into a table lookup. nil results are
-- cached too (stored as `false`), since those are the expensive full walks.
local find_cache = {}

-- Walk up from `path` looking for a directory named D<digits>, optionally
-- followed by a "-slug" suffix (legacy worktree layout). `path` may be a file
-- or a directory. Returns (revision_id, worktree_root) or nil. The revision id
-- is the clean D<digits> part; the worktree root is the matched directory
-- itself (which is the git worktree root, so inline-comment paths resolve
-- relative to it).
function M.find(path)
  if not path or path == "" then return nil end
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")

  local hit = find_cache[path]
  if hit ~= nil then
    if hit == false then return nil end
    return hit.id, hit.root
  end

  local dir
  if vim.fn.isdirectory(path) == 1 then
    dir = path
  else
    dir = vim.fs.dirname(path)
  end
  while dir and dir ~= "" and dir ~= "/" do
    local name = vim.fs.basename(dir)
    if name then
      local id = name:match("^(D%d+)$") or name:match("^(D%d+)%-")
      if id then
        find_cache[path] = { id = id, root = dir }
        return id, dir
      end
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  find_cache[path] = false
  return nil
end

-- Best-effort "where am I?" for commands invoked from buffers without a file
-- name (snacks dashboard, scratch buffers, etc.). Prefers the buffer name,
-- then the window-local cwd, then the global cwd.
function M.context_path(buf)
  local name = buf and vim.api.nvim_buf_get_name(buf) or ""
  if name ~= "" then return name end
  local ok, cwd = pcall(vim.fn.getcwd, 0)
  if ok and cwd and cwd ~= "" then return cwd end
  return vim.fn.getcwd()
end

-- Relative path of buf within worktree root, or nil if outside.
function M.rel_path(buf, root)
  local full = vim.api.nvim_buf_get_name(buf)
  if full == "" then return nil end
  full = vim.fn.fnamemodify(full, ":p")
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if full:sub(1, #root + 1) ~= root .. "/" then return nil end
  return full:sub(#root + 2)
end

return M
