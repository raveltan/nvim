-- Per-root cache shared by selector_index and module_index: one value per search
-- root (worktrees keep separate indexes), one in-flight build that concurrent
-- callers share (completion asks on every keystroke), and a revision counter for
-- consumers memoizing derived views.
local M = {}

-- Wrap a builder into a cache. `build(root, rg_run, cb)` produces the value.
function M.new(build)
  local cache, pending, revision = {}, {}, {}

  local api = {}

  function api.revision(root)
    return revision[root] or 0
  end

  function api.bump(root)
    revision[root] = (revision[root] or 0) + 1
  end

  function api.peek(root)
    return cache[root]
  end

  function api.invalidate(root)
    cache[root] = nil
  end

  -- Synchronous `cb` on a hit, otherwise one build every concurrent caller waits
  -- on. Nothing builds at startup; the first lookup that needs it pays.
  function api.get(root, rg_run, cb)
    local value = cache[root]
    if value then return cb(value) end
    local queue = pending[root]
    if queue then
      queue[#queue + 1] = cb
      return
    end
    pending[root] = { cb }
    build(root, rg_run, function(built)
      cache[root] = built
      api.bump(root)
      local queued = pending[root] or {}
      pending[root] = nil
      for _, f in ipairs(queued) do
        f(built)
      end
    end)
  end

  return api
end

-- Files outside the root can't smuggle entries in, and spec files are excluded
-- from the builds.
function M.tracks(root, file)
  return file:sub(1, #root) == root and not file:match("%.spec%.ts$")
end

return M
