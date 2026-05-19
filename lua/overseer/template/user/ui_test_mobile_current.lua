local h = require("gaf.ui_test")
return {
  name = "ui test mobile (current)",
  params = h.params,
  builder = h.build_task("ui:main:mobile"),
  condition = h.condition,
}
