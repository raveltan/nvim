local M = {}

function M.filter_mason_servers(servers)
  return vim.tbl_filter(function(s) return s ~= "tailwindcss" end, servers)
end

function M.basedpyright_extra_paths()
  return { "libgafthrift", "restutils" }
end

return M
