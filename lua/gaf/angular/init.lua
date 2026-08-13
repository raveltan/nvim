-- Navigate and complete Angular components with treesitter + ripgrep. No LSP.
--
-- Tuned for INLINE-template Angular (`@Component({ template: `...` })`): both
-- selector definitions and their usages live in `.ts` files, and the `angular`
-- parser auto-injects into the template backtick string (see
-- lua/plugins/treesitter.lua), which is what makes tag/attribute reads precise.
-- Projects with external `.component.html` templates get the .ts-side navigation
-- but not the in-template reads, which need the injected tree.
--
-- Not GAF-specific, but gated with the rest of the GAF tooling because a
-- repo-wide selector index only pays for itself in the webapp.
--
--   search.lua      rg + jump/picker plumbing, the search root
--   patterns.lua    the rg patterns every lookup chases
--   ts.lua          treesitter helpers (traversal, decorators, edit ranges)
--   context.lua     what the cursor is on inside a template
--   nav.lua         gd, parents, component-by-name
--   routes.lua      URL string -> routing module
--   component.lua   reading a component file (inputs, facts, import specs, enums)
--   completion.lua  the data behind the completion source
--   edits.lua       the text edits an accepted completion needs
--   *_index.lua     the two repo-wide indexes tag completion reads
--   inputs_source.lua  the blink.cmp source itself
local module_index = require("gaf.angular.module_index")
local nav = require("gaf.angular.nav")
local routes = require("gaf.angular.routes")
local search = require("gaf.angular.search")
local selector_index = require("gaf.angular.selector_index")

local M = {}

-- Rebuild the index for the current file's root, after a rename or branch switch
-- moves more than write-time patching can follow. The NgModule index is dropped,
-- not rebuilt: the next NgModule-declared tag completion builds it.
function M.reindex()
  local root = search.buf_root(0)
  selector_index.invalidate(root)
  module_index.invalidate(root)
  selector_index.get(root, search.rg_run, function(idx)
    local n = 0
    for _ in pairs(idx) do n = n + 1 end
    search.notify(n .. " selectors indexed under " .. root)
  end)
end

-- Buffer-local `gd` shadows the global snacks `gd` on TS buffers, and falls back
-- to LSP definition when the cursor isn't on an Angular target.
--   gd         -> definition under cursor: tag (component), attr (@Input/@Output),
--                 class (scss), a symbol in a binding expression (its TS def), or
--                 a template-local (@if `as`, @for var, @let, #ref) binding site
--   <leader>cp -> parent components (callers that use this selector, "up")
--   <leader>cG -> prompt for a component name (class or selector) -> its definition
--   <leader>cR -> URL string under cursor -> routing module that handles it
function M.setup()
  local group = vim.api.nvim_create_augroup("angular_nav", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "typescript",
    callback = function(ev)
      local function bmap(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
      end
      bmap("gd", function()
        if not nav.goto_definition() then
          Snacks.picker.lsp_definitions()
        end
      end, "Go to definition (Angular template-aware)")
      bmap("<leader>cp", nav.goto_parents, "Angular: go to parent components")
      bmap("<leader>cG", nav.goto_component_prompt, "Angular: go to component by name")
      bmap("<leader>cR", routes.goto_route, "Angular: go to route module for URL")
    end,
  })
  -- update_file is a no-op on a root nobody has indexed, so a write never
  -- triggers the repo-wide rg.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.ts",
    callback = function(ev)
      local file = vim.api.nvim_buf_get_name(ev.buf)
      local root = search.search_root(file)
      selector_index.update_file(root, file)
      module_index.update_file(root, file)
    end,
  })
  vim.api.nvim_create_user_command("AngularReindex", M.reindex,
    { desc = "Angular: rebuild the component selector index" })
end

return M
