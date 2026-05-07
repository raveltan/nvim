local h = require("config.ui_test")
return {
  name = "ui test mobile devtools (current)",
  params = h.params,
  builder = h.build_task("ui:main:mobile", { DEVTOOLS = "true" }),
  condition = h.condition,
}
