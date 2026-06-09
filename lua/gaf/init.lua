local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  -- Tag matching (`%`, `i%`/`a%`) moved to the general tagmatch.nvim plugin -- it
  -- handles Angular inline templates plus html/jsx/eruby/php/... for everyone.

  -- Angular selector navigation on component buffers (treesitter + rg, no LSP):
  --   <leader>cp -> parent components (callers that use this selector, "up")
  --   <leader>cg -> definition under cursor: tag (component), attr (@Input/@Output), or class (scss)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "typescript",
    callback = function(ev)
      vim.keymap.set("n", "<leader>cp", function()
        require("gaf.angular").goto_parents()
      end, { buffer = ev.buf, desc = "Angular: go to parent components" })
      vim.keymap.set("n", "<leader>cg", function()
        require("gaf.angular").goto_definition()
      end, { buffer = ev.buf, desc = "Angular: go to def (tag/attr)" })
    end,
  })
end

return M
