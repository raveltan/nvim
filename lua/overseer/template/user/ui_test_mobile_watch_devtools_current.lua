local h = require("config.ui_test")
return {
  name = "ui test mobile watch devtools (current)",
  params = h.params,
  builder = h.build_task("ui:main:mobile:watch", { DEVTOOLS = "true" }),
  condition = h.condition,
}
