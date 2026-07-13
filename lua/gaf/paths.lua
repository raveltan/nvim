local M = {}

M.dev_root = vim.fn.expand("~/freelancer-dev")
M.fl_gaf = vim.fn.expand("~/freelancer-dev/fl-gaf")
M.remote_root = "/mnt/gaf"
M.dev_dns = "rtanjaya"

-- Walk upward from `from` (file or dir; default cwd) to the first directory
-- containing relative path `rel` (e.g. "bin/run-tests"). Shared by xdebug,
-- test_infra, etc. — was three hand-rolled loops.
function M.find_root(rel, from)
  local dir = from or vim.fn.getcwd()
  if vim.fn.isdirectory(dir) == 0 then dir = vim.fs.dirname(dir) end
  while dir and dir ~= "" and dir ~= "/" do
    if vim.uv.fs_stat(dir .. "/" .. rel) then return dir end
    dir = vim.fs.dirname(dir)
  end
  return nil
end

-- Webapp root = directory whose package.json defines the "ui:main" script.
-- Handles both shapes: `start` is inside the webapp itself (UI-test spec
-- buffers) or the webapp/ is a child of an ancestor (monorepo cwd).
function M.webapp_root(start)
  local function is_webapp(dir)
    local pkg = dir .. "/package.json"
    if vim.fn.filereadable(pkg) ~= 1 then return false end
    local content = table.concat(vim.fn.readfile(pkg), "\n")
    return content:find('"ui:main"', 1, true) ~= nil
  end
  local dir = start or vim.fn.getcwd()
  if vim.fn.isdirectory(dir) == 0 then dir = vim.fs.dirname(dir) end
  while dir and dir ~= "" and dir ~= "/" do
    if is_webapp(dir) then return dir end
    local child = dir .. "/webapp"
    if vim.fn.isdirectory(child) == 1 and is_webapp(child) then return child end
    dir = vim.fs.dirname(dir)
  end
  return nil
end

return M
