local h = require("config.ui_test")
return {
  name = "ui test devtools (current)",
  params = h.params,
  builder = h.build_task("ui:main", { DEVTOOLS = "true" }),
  condition = h.condition,
}
