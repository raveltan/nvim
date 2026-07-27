-- Laravel/Blade-aware `gd`, in the shape lua/angular/init.lua established:
-- a buffer-local map that resolves what the framework knows, and returns false
-- so the caller falls through to `Snacks.picker.lsp_definitions()` otherwise.
--
-- `gd` is the key that matters here. Most of what you chase in a Blade view is
-- a *definition* — the component behind a tag, the property behind `{{ $x }}`,
-- the route behind `route('…')` — not a file path, and intelephense is not
-- attached to blade at all, so plain `gd` did nothing there. `gf` still works
-- and shares the same resolvers (lua/artisan/gf.lua); it just is not the key
-- you should have to reach for.
local M = {}

local function open(path, line)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if line then
    vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(0)), 0 })
    vim.cmd("normal! zz")
  end
  return true
end

--- `{{ $days }}`, `@if ($showArchived)`, `$this->save()` inside a component's
--- own template → the declaration in its class.
---@return boolean handled
local function template_member()
  if vim.bo.filetype ~= "blade" then return false end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Widen to the identifier under the cursor, then check what introduces it.
  local s, e = col, col
  while s > 1 and line:sub(s - 1, s - 1):match("[%w_]") do s = s - 1 end
  while e < #line and line:sub(e + 1, e + 1):match("[%w_]") do e = e + 1 end
  local word = line:sub(s, e)
  if word == "" or not word:match("^[%w_]+$") then return false end

  local is_var = line:sub(s - 1, s - 1) == "$"
  local is_member = line:sub(math.max(1, s - 2), s - 1) == "->"
  if not is_var and not is_member then return false end

  local parsed = require("artisan.props").for_current_component(0)
  for _, list in ipairs({ parsed.props, parsed.methods }) do
    for _, entry in ipairs(list) do
      if entry.name == word and entry.path then
        if entry.line then return open(entry.path, entry.line) end
        -- @props entries have no row of their own (the directive body is
        -- re-parsed standalone), so locate the key by text.
        if entry.pattern then
          local ok, lines = pcall(vim.fn.readfile, entry.path)
          if ok then
            for i, text in ipairs(lines) do
              if text:find(entry.pattern) then return open(entry.path, i) end
            end
          end
        end
        return open(entry.path)
      end
    end
  end
  return false
end

--- Try each Laravel-aware resolver. Returns false when none of them claims the
--- cursor, which is the signal to fall back to the language server.
---@return boolean handled
function M.goto_definition()
  local refs = require("artisan.refs")
  if require("artisan.livewire").goto_component() then return true end
  if template_member() then return true end
  if refs.route() then return true end
  if refs.lang() then return true end

  -- Blade-only from here: in a php buffer intelephense is authoritative for
  -- everything else, and these resolvers would shadow it.
  if vim.bo.filetype ~= "blade" then return false end
  return require("artisan.gf").blade_nav() or require("artisan.gf").laravel_nvim()
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("artisan_gd", { clear = true }),
    pattern = { "php", "blade" },
    callback = function(ev)
      vim.keymap.set("n", "gd", function()
        if not M.goto_definition() then
          Snacks.picker.lsp_definitions()
        end
      end, { buffer = ev.buf, desc = "Go to definition (Laravel/Blade aware)" })
    end,
  })
end

return M
