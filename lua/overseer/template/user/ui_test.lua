-- Single provider replacing the former 8 near-identical ui_test_*_current.lua
-- files. Yields one template per (variant × devtools) combination. Module name
-- still matches the `^overseer%.template%.user%.` gate in plugins/workflow.lua,
-- so it stays disabled unless GAF is enabled.
local h = require("gaf.ui_test")

-- script suffix → human label fragment
local variants = {
  { script = "ui:main", label = "" },
  { script = "ui:main:mobile", label = "mobile " },
  { script = "ui:main:watch", label = "watch " },
  { script = "ui:main:mobile:watch", label = "mobile watch " },
}

local function templates()
  local out = {}
  for _, v in ipairs(variants) do
    for _, dt in ipairs({ false, true }) do
      local name = "ui test " .. v.label .. (dt and "devtools " or "") .. "(current)"
      out[#out + 1] = {
        name = name,
        params = h.params,
        builder = h.build_task(v.script, dt and { DEVTOOLS = "true" } or nil),
        condition = h.condition,
      }
    end
  end
  return out
end

return {
  condition = h.condition,
  generator = function(_, cb)
    cb(templates())
  end,
}
