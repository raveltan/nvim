local h = require("config.ui_test")
return {
  name = "ui test mobile watch (current)",
  params = h.params,
  builder = h.build_task("ui:main:mobile:watch"),
  condition = h.condition,
}
