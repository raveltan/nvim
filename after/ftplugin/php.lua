vim.keymap.set("i", ".", function()
  local col = vim.fn.col(".") - 1
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  if before:match("[%w_%)%]>]$") then
    return "->"
  end
  return "."
end, { buffer = true, expr = true })
