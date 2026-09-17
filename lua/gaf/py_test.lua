-- pytest in the api-mono repo, run as overseer tasks. `./run.sh test <service>
-- [paths]` builds a per-service Docker image and runs pytest inside it, so the
-- service is not a detail we can guess from cwd: it is the first path segment
-- under the repo root (rest/, users_dao/, libgafthrift/, ...), each with its own
-- Dockerfile under <service>/lib/docker/test/. Derived from the buffer, so nvim
-- started anywhere still routes rest/tests/test_sla_api.py to `test rest`.
--
-- The task shape lives here; the templates built from it are in
-- lua/overseer/template/user/py_test.lua, which overseer finds on the runtimepath.
local M = {}

-- Repo root = the dir whose run.sh implements the `test <folder_name>` verb.
-- Matching on run.sh alone would also match fl-gaf and half of ~/freelancer-dev.
local function root(from)
  local dir = require("gaf.paths").find_root("run.sh", from or vim.api.nvim_buf_get_name(0))
  while dir do
    local ok, lines = pcall(vim.fn.readfile, dir .. "/run.sh")
    if ok and table.concat(lines, "\n"):find("./run.sh test <folder_name>", 1, true) then
      return dir
    end
    dir = require("gaf.paths").find_root("run.sh", vim.fs.dirname(dir))
  end
  return nil
end

M.root = root

--- Returns repo_root, service, path_relative_to_service for the current buffer.
function M.context(bufnr)
  local abs = vim.api.nvim_buf_get_name(bufnr or 0)
  if abs == "" then return nil end
  local dir = root(abs)
  if not dir then return nil end
  local rel = abs:sub(#dir + 2)
  local service, rest = rel:match("^([^/]+)/(.+)$")
  -- A Dockerfile under <service>/lib/docker/test/ is what run.sh needs; without
  -- one the run fails on `docker build` rather than telling you the folder is
  -- not a testable service.
  if not service or vim.fn.isdirectory(dir .. "/" .. service .. "/lib/docker/test") == 0 then
    return nil
  end
  return dir, service, rest
end

--- pytest node id for the test under the cursor, e.g.
--- "tests/test_sla_api.py::SlaTestCase::test_create". Falls back to the file
--- when the cursor is not inside a def test_*.
function M.nearest(bufnr)
  local _, _, rel = M.context(bufnr)
  if not rel then return nil end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, lnum, false)
  local fn, cls
  for i = #lines, 1, -1 do
    local l = lines[i]
    if not fn then fn = l:match("^%s+def%s+(test_[%w_]+)") or l:match("^def%s+(test_[%w_]+)") end
    if fn and not cls then cls = l:match("^class%s+([%w_]+)") end
    if fn and cls then break end
  end
  if not fn then return rel end
  return rel .. "::" .. (cls and cls .. "::" or "") .. fn
end

--- target: "file" | "nearest" | "service"; flags are run.sh flags, e.g. {"--watch"}.
function M.build_task(target, flags)
  return function(params)
    local dir, service, rel = M.context()
    local args = { "test", service }
    if target == "nearest" then
      args[#args + 1] = M.nearest()
    elseif target == "file" then
      args[#args + 1] = rel
    end
    vim.list_extend(args, flags or {})
    if params and params.extra and params.extra ~= "" then
      vim.list_extend(args, vim.split(params.extra, "%s+"))
    end
    return {
      cmd = { "./run.sh", unpack(args) },
      cwd = dir,
      -- run.sh only rebuilds thrift stubs when THRIFT_PATH is set, and mounts
      -- the local gen-py over the image's when it is. Inherited from the shell
      -- if exported; nothing to do here.
    }
  end
end

M.params = {
  extra = {
    type = "string",
    name = "extra args",
    desc = "Extra run.sh args (e.g. --report)",
    default = "",
    optional = true,
  },
}

M.condition = {
  callback = function() return select(2, M.context()) ~= nil end,
}

return M
