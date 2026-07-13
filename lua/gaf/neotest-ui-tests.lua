-- Neotest adapter for Freelancer GAF webapp UI tests.
-- Run via: cd webapp && SPECS="<spec-name>" yarn ui:<project>

local lib = require("neotest.lib")
local async = require("neotest.async")

---@type neotest.Adapter
local adapter = { name = "neotest-ui-tests" }

---@param path string
---@return string|nil
local function find_webapp_root(path)
  return require("gaf.paths").webapp_root(path)
end

---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
  if not file_path then
    return false
  end
  return file_path:match("ui%-tests/src/.+%.spec%.ts$") ~= nil
end

function adapter.root(path)
  if path:match("ui%-tests/src/") then
    return find_webapp_root(path)
  end
  return nil
end

function adapter.filter_dir(name)
  return name ~= "node_modules" and name ~= "dist" and name ~= ".angular"
end

-- File-level only — SPECS filters by filename and Karma can't target individual tests.
function adapter.discover_positions(path)
  return lib.treesitter.parse_positions(path, "", {})
end

---@param args neotest.RunArgs
---@return neotest.RunSpec
function adapter.build_spec(args)
  local position = args.tree:data()
  local path = position.path

  local project = path:match("projects/([^/]+)/ui%-tests/src/")
  if not project then
    return {}
  end

  local webapp_root = find_webapp_root(path)
  if not webapp_root then
    return {}
  end

  local specs_pattern = vim.fn.fnamemodify(path, ":t")
  local spec_name = specs_pattern:gsub("%.spec%.ts$", "")

  local is_mobile = false
  local is_watch = false
  if args.extra_args then
    for _, arg in ipairs(args.extra_args) do
      if arg == "--mobile" then
        is_mobile = true
      elseif arg == "--watch" then
        is_watch = true
      end
    end
  end

  local yarn_cmd = "yarn ui:" .. project
  if is_mobile then
    yarn_cmd = yarn_cmd .. ":mobile"
  end
  if is_watch then
    yarn_cmd = yarn_cmd .. ":watch:instant"
  end
  local results_path = async.fn.tempname() .. ".txt"

  local command = string.format(
    "cd %s && SPECS=%q %s 2>&1 | tee %s; exit ${PIPESTATUS[0]}",
    vim.fn.shellescape(webapp_root),
    specs_pattern,
    yarn_cmd,
    results_path
  )

  return {
    command = { "bash", "-c", command },
    context = {
      results_path = results_path,
      file = path,
      spec_name = spec_name,
    },
  }
end

---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
  local output_path = result.output
  local status = result.code == 0 and "passed" or "failed"

  local results = {}
  for _, pos in tree:iter() do
    results[pos.id] = { status = status, output = output_path }
  end

  if spec.context.results_path then
    pcall(os.remove, spec.context.results_path)
  end

  return results
end

return adapter
