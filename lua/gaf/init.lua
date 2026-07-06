local M = {}

function M.setup()
  if not vim.g.gaf then return end
  require("gaf.xdebug").setup()
  -- Tag matching (`%`, `i%`/`a%`) moved to the in-repo lua/tagmatch/ module -- it
  -- handles Angular inline templates plus html/jsx/eruby/php/... for everyone.

  -- Angular selector navigation on component buffers (treesitter + rg, no LSP):
  --   <leader>cp -> parent components (callers that use this selector, "up")
  --   gd         -> definition under cursor: tag (component), attr (@Input/@Output),
  --                 or class (scss); falls back to LSP definition on plain TS
  --   <leader>cG -> prompt for a component name (class or selector) -> its definition
  --   <leader>cR -> URL string under cursor -> routing module that handles it
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "typescript",
    callback = function(ev)
      vim.keymap.set("n", "<leader>cp", function()
        require("gaf.angular").goto_parents()
      end, { buffer = ev.buf, desc = "Angular: go to parent components" })
      -- Buffer-local override shadows the global snacks `gd` on TS buffers only:
      -- try Angular template navigation first, else the normal LSP definition.
      vim.keymap.set("n", "gd", function()
        if not require("gaf.angular").goto_definition() then
          Snacks.picker.lsp_definitions()
        end
      end, { buffer = ev.buf, desc = "Go to definition (Angular template-aware)" })
      vim.keymap.set("n", "<leader>cG", function()
        require("gaf.angular").goto_component_prompt()
      end, { buffer = ev.buf, desc = "Angular: go to component by name" })
      vim.keymap.set("n", "<leader>cR", function()
        require("gaf.angular").goto_route()
      end, { buffer = ev.buf, desc = "Angular: go to route module for URL" })
    end,
  })
end

return M
