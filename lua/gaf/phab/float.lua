-- Read-only markdown float, rendered through Snacks.win so it picks up the
-- same border, backdrop and dismiss keys as every other floating surface in
-- this config. Content is plain markdown; treesitter does the highlighting.

local M = {}

---@param opts { title: string, lines: string[], footer?: string, keys?: table }
function M.open(opts)
  return Snacks.win({
    text = opts.lines,
    ft = "markdown",
    enter = true,
    border = "rounded",
    title = " " .. opts.title .. " ",
    footer = opts.footer and (" " .. opts.footer .. " ") or nil,
    width = 0.7,
    height = 0.7,
    wo = { wrap = true, linebreak = true, cursorline = true, conceallevel = 2 },
    bo = { modifiable = false },
    keys = vim.tbl_extend("force", {
      q = "close",
      esc = { "<esc>", "close", mode = "n" },
    }, opts.keys or {}),
  })
end

return M
