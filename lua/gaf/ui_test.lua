local M = {}

-- Find a webapp/ directory (with package.json) at or above cwd.
function M.resolve_webapp_cwd()
  local cwd = vim.fn.getcwd()
  if cwd:match("/webapp$") and vim.fn.filereadable(cwd .. "/package.json") == 1 then
    return cwd
  end
  local dir = cwd
  while dir ~= "/" and dir ~= "" do
    local candidate = dir .. "/webapp"
    if vim.fn.isdirectory(candidate) == 1
        and vim.fn.filereadable(candidate .. "/package.json") == 1 then
      return candidate
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

function M.has_webapp()
  return M.resolve_webapp_cwd() ~= nil
end

-- yarn_script: package.json script name (e.g. "ui:main:watch")
-- extra_env: optional extra env vars (e.g. { DEVTOOLS = "true" })
function M.build_task(yarn_script, extra_env)
  return function(params)
    if params.spec == nil or params.spec == "" then
      params.spec = vim.fn.expand("%:t")
    end
    local env = { SPECS = params.spec }
    if extra_env then
      for k, v in pairs(extra_env) do env[k] = v end
    end
    return {
      cmd = { "yarn", yarn_script },
      cwd = M.resolve_webapp_cwd(),
      env = env,
      components = { "default" },
    }
  end
end

M.params = {
  spec = {
    type = "string",
    name = "SPECS",
    desc = "Spec pattern (blank = current file)",
    default = "",
    optional = true,
  },
}

M.condition = {
  callback = function() return vim.g.gaf and M.has_webapp() end,
}

return M
