local h = require("config.ui_test")
return {
  name = "ui test (current)",
  params = h.params,
  builder = h.build_task("ui:main"),
  condition = h.condition,
}
