local h = require("config.ui_test")
return {
  name = "ui test watch devtools (current)",
  params = h.params,
  builder = h.build_task("ui:main:watch", { DEVTOOLS = "true" }),
  condition = h.condition,
}
