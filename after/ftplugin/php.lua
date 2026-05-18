vim.keymap.set("i", "$$", function()
  local col = vim.fn.col(".") - 1
  local before = vim.api.nvim_get_current_line():sub(1, col)
  if before:match("[%w_$]$") then
    return "$$"
  end
  return "$this->"
end, { buffer = true, expr = true, desc = "PHP: $$ -> $this->" })
