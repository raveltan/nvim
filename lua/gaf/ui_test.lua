local M = {}

-- Webapp root at or above cwd (shared resolver in gaf.paths).
function M.resolve_webapp_cwd()
  return require("gaf.paths").webapp_root()
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
