-- Buffer-local `gf` for php and blade buffers.
--
-- Three plugins want this key and none of them can be left to arbitrate it:
--
--   * blade-nav installs its own buffer-local `gf` and, on a miss, replays
--     whatever global `gf` mapping existed when it was set up. laravel.nvim's
--     mapping (from its README) is an `expr` Lua callback, so its `rhs` is nil —
--     blade-nav fed that nil to nvim_replace_termcodes and EVERY unresolved
--     `gf` in a php/blade buffer raised `E5108`, including plain file paths.
--   * blade-nav's Livewire and component handlers predate Livewire 4 and answer
--     with paths that do not exist (see lua/artisan/livewire.lua).
--
-- So both plugins' `gf` registrations are switched off in
-- lua/plugins/laravel.lua and the chain is made explicit here. Each step
-- returns whether it handled the cursor, and the last one is always plain `gf`.
local M = {}

--- Livewire 4 / Blade component tags — ours, because blade-nav gets these wrong.
local function components()
  return require("artisan.livewire").goto_component()
end

--- @include, @extends, config(), view(), Inertia pages, …
--- Exported so lua/artisan/gd.lua can reuse the same step.
function M.blade_nav()
  local ok, targets = pcall(require, "blade-nav.targets")
  if not ok then return false end
  local made, context = pcall(function() return require("blade-nav.core.context").create() end)
  if not made or not context then return false end
  local resolved_ok, resolved = pcall(targets.resolve_target, context)
  return resolved_ok and resolved ~= nil and resolved ~= false
end

--- route(), env(), and laravel.nvim's own view()/config()/Inertia resolution.
--- Its route handling is the reason this step exists at all: blade-nav shells
--- out `artisan route:list --columns=…`, an option Laravel 13 removed, so its
--- route resolution silently returns nothing.
function M.laravel_nvim()
  if not _G.Laravel then return false end
  local ok, on_resource = pcall(function() return Laravel.app("gf").cursorOnResource() end)
  if not ok or not on_resource then return false end
  pcall(function() Laravel.commands.run("gf") end)
  return true
end

function M.gf()
  local refs = require("artisan.refs")
  if components() then return end
  if refs.route() then return end
  if refs.lang() then return end
  if M.blade_nav() then return end
  if M.laravel_nvim() then return end
  -- Plain path under the cursor. Report vim's own message (missing file, etc)
  -- rather than letting the keymap callback dump a Lua traceback.
  local ok, err = pcall(vim.cmd, "normal! gf")
  if not ok then
    vim.notify(tostring(err):gsub("^Vim%(.-%):", ""), vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("artisan_gf", { clear = true }),
    pattern = { "php", "blade" },
    callback = function(ev)
      vim.keymap.set("n", "gf", M.gf, {
        buffer = ev.buf,
        desc = "Go to file (Livewire/Blade/Laravel aware)",
      })
    end,
  })
end

return M
