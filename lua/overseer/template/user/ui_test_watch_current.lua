local h = require("config.ui_test")
return {
  name = "ui test watch (current)",
  params = h.params,
  builder = h.build_task("ui:main:watch"),
  condition = h.condition,
}
