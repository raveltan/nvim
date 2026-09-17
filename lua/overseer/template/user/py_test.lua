-- api-mono pytest tasks. The service name is in the task label, so `<leader>or`
-- from a rest/ buffer and from a users_dao/ buffer list visibly different
-- entries instead of an ambiguous "run tests". Module name matches the
-- `^overseer%.template%.user%.` pattern lua/plugins/workflow.lua disables outside
-- GAF, and the provider condition below rejects a non-api-mono buffer.
local h = require("gaf.py_test")

local TARGETS = {
  { target = "nearest", label = "nearest test" },
  { target = "file", label = "file" },
  { target = "service", label = "all tests" },
}

return {
  condition = h.condition,
  generator = function(_, cb)
    local _, service = h.context()
    local out = {}
    for _, t in ipairs(TARGETS) do
      for _, watch in ipairs({ false, true }) do
        out[#out + 1] = {
          name = ("pytest %s: %s%s"):format(service, watch and "watch " or "", t.label),
          params = h.params,
          builder = h.build_task(t.target, watch and { "--watch" } or nil),
        }
      end
    end
    cb(out)
  end,
}
