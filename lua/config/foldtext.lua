-- Custom foldtext: fold's first line + count of hidden lines.
-- vim.treesitter.foldtext() does not exist in Neovim 0.12, so we hand-roll this.
-- Returning a virtual-text chunk list keeps the count in the Folded highlight.
local M = {}

function M.foldtext()
  local fs = vim.v.foldstart
  local line = vim.api.nvim_buf_get_lines(0, fs - 1, fs, false)[1] or ""
  line = line:gsub("\t", string.rep(" ", vim.bo.tabstop))
  local count = vim.v.foldend - vim.v.foldstart + 1
  return {
    { line, "Normal" },
    { "  ", "" },
    { ("󰁂 %d lines"):format(count), "Folded" },
  }
end

return M
