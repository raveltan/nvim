return {
  name = "fli provision (devbox)",
  builder = function()
    return {
      cmd = { "fli", "provision" },
      components = { "default" },
    }
  end,
  condition = {
    callback = function() return vim.g.gaf end,
  },
}
