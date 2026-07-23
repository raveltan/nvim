local M = {}

local API_ROOT = vim.fn.expand("~/freelancer-dev/api")

function M.filter_mason_servers(servers)
  return vim.tbl_filter(function(s) return s ~= "tailwindcss" end, servers)
end

-- The api repo is a multi-package monorepo: each top-level service dir is its
-- own setuptools project and the importable package sits one level INSIDE it,
-- often under a different name (rest/ -> api, users_midlayer/ -> users_mid).
-- So the OUTER dirs are the import roots pyright needs. The repo root itself
-- is included so pyright discovers gaf_thrift-stubs/ as PEP-561 stubs for the
-- gaf_thrift pip package (the stubs dir is gitignored; regenerate it from the
-- thrift repo via run.sh build_thrift_definitions if missing).
function M.basedpyright_extra_paths()
  local paths = { API_ROOT }
  local services = {
    "rest", "restutils", "libgafthrift", "pii_store",
    "users_midlayer", "users_dao",
    "messages_midlayer", "messages_dao",
    "projects_midlayer", "projects_dao",
  }
  for _, s in ipairs(services) do
    table.insert(paths, API_ROOT .. "/" .. s)
  end
  return paths
end

-- py3.11 venv (pyenv, lives outside the repo) holding the api repo's
-- third-party deps installed from the Nexus mirror, so Flask/boto3/gaf_thrift
-- resolve. Created with: pyenv virtualenv 3.11.14 api311
function M.basedpyright_python_path()
  return vim.fn.expand("~/.pyenv/versions/api311/bin/python")
end

return M
