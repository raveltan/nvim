-- Livewire / Volt navigation.
--
-- The two Laravel plugins cover the pieces that look like Blade: blade-nav
-- resolves `<livewire:foo />` and `@livewire('foo')` under `gf`, laravel.nvim's
-- code actions copy/move/delete components. Neither moves between the files that
-- make up one component, which is the move you make dozens of times an hour.
--
-- Livewire 4 made that harder by shipping three component shapes, and
-- `make:livewire` defaults to the one that didn't exist before (verified against
-- livewire/livewire v4.3.3):
--
--   sfc (default)  resources/views/components/admin/⚡user-table.blade.php
--                  class and view in ONE file; `--emoji=false` drops the ⚡ and
--                  makes the path indistinguishable from an anonymous Blade
--                  component, so those are identified by content instead.
--   mfc            resources/views/components/billing/⚡invoice/
--                    invoice.php  invoice.blade.php  (+ optional .js / .css)
--   class (legacy) app/Livewire/Reports/Sales.php
--                  + resources/views/livewire/reports/sales.blade.php
--                  (Livewire 2 used app/Http/Livewire)
--
-- `related()` returns every sibling of whichever shape the current file belongs
-- to, so one keymap covers all of them.
local M = {}

local CLASS_DIRS = { "app/Livewire", "app/Http/Livewire" }
local VIEW_DIR = "resources/views/livewire"
local COMPONENT_DIR = "resources/views/components"

-- Livewire's own marker for "this is a component, not an anonymous Blade
-- partial". Three bytes; Lua handles it as an ordinary literal.
local BOLT = "⚡"

--- Laravel's Str::kebab: a delimiter before every uppercase letter that follows
--- another character. Written as a loop rather than a gsub because the pattern
--- form collapses runs of capitals ("APIToken" must become "a-p-i-token", which
--- is what Livewire's own view resolution produces).
---@param s string
---@return string
local function kebab(s)
  local out = { s:sub(1, 1) }
  for i = 2, #s do
    local c = s:sub(i, i)
    out[#out + 1] = c:match("%u") and ("-" .. c) or c
  end
  return table.concat(out):lower()
end

---@param s string
---@return string
local function studly(s)
  local out = {}
  for part in s:gmatch("[^%-]+") do
    out[#out + 1] = part:sub(1, 1):upper() .. part:sub(2)
  end
  return table.concat(out)
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

--- True when `file` starts with `root .. "/" .. dir .. "/"`; returns the
--- remainder so callers don't have to recompute the prefix length.
---@return string|nil
local function under(file, root, dir)
  local prefix = root .. "/" .. dir .. "/"
  if file:sub(1, #prefix) == prefix then return file:sub(#prefix + 1) end
  return nil
end

--- The view a legacy class-based component renders. Prefers what the class
--- actually says — a `view('…')` inside render() — and only falls back to the
--- naming convention, so components with a custom view still navigate.
local function view_for_class(root, file, rel)
  local ok, lines = pcall(vim.fn.readfile, file)
  if ok then
    for _, line in ipairs(lines) do
      local name = line:match("view%(%s*['\"]([%w%._%-/]+)['\"]")
      if name then
        return root .. "/resources/views/" .. name:gsub("%.", "/") .. ".blade.php"
      end
    end
  end

  local segments = {}
  for part in rel:gsub("%.php$", ""):gmatch("[^/]+") do
    segments[#segments + 1] = kebab(part)
  end
  return root .. "/" .. VIEW_DIR .. "/" .. table.concat(segments, "/") .. ".blade.php"
end

--- Does this Blade file declare a Livewire single-file component? Used only for
--- the emoji-less sfc case, where the path alone cannot tell a component from an
--- anonymous Blade component.
local function is_sfc(file)
  local ok, lines = pcall(vim.fn.readfile, file, "", 40)
  if not ok then return false end
  local head = table.concat(lines, "\n")
  return head:find("Livewire\\Component", 1, true) ~= nil
    or head:find("new class extends Component", 1, true) ~= nil
    or head:find("Livewire\\Volt", 1, true) ~= nil
end

--- Every other file belonging to the same component as `file`.
---@param root string
---@param file string absolute, normalized
---@return { path: string, label: string }[] related
---@return string kind  "class" | "view" | "mfc" | "sfc" | "none"
function M.related(root, file)
  local out = {}

  -- Legacy class -> its view.
  for _, dir in ipairs(CLASS_DIRS) do
    local rel = under(file, root, dir)
    if rel then
      local view = view_for_class(root, file, rel)
      if exists(view) then out[#out + 1] = { path = view, label = "view" } end
      return out, "class"
    end
  end

  -- Legacy view -> its class. A project can be mid-migration from
  -- app/Http/Livewire to app/Livewire, so every candidate that exists is offered.
  local view_rel = under(file, root, VIEW_DIR)
  if view_rel then
    local segments = {}
    for part in view_rel:gsub("%.blade%.php$", ""):gmatch("[^/]+") do
      segments[#segments + 1] = studly(part)
    end
    local tail = table.concat(segments, "/") .. ".php"
    for _, dir in ipairs(CLASS_DIRS) do
      local candidate = root .. "/" .. dir .. "/" .. tail
      if exists(candidate) then out[#out + 1] = { path = candidate, label = dir } end
    end
    return out, "view"
  end

  -- Livewire 4 sfc / mfc, both under resources/views/components.
  local comp_rel = under(file, root, COMPONENT_DIR)
  if not comp_rel then return out, "none" end

  local dir = vim.fs.dirname(file)
  -- mfc: the *directory* carries the ⚡ marker and every member shares its name.
  if vim.fs.basename(dir):sub(1, #BOLT) == BOLT then
    local base = vim.fn.fnamemodify(file, ":t"):gsub("%.blade%.php$", ""):gsub("%.[%w]+$", "")
    for name, _ in vim.fs.dir(dir) do
      local candidate = dir .. "/" .. name
      if candidate ~= file and name:match("^" .. vim.pesc(base) .. "%.") then
        out[#out + 1] = { path = candidate, label = name:gsub("^" .. vim.pesc(base) .. "%.", "") }
      end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out, "mfc"
  end

  -- sfc: one file, nothing to move to. Identified by the ⚡ prefix, or by
  -- content when the component was generated with --emoji=false.
  if vim.fs.basename(file):sub(1, #BOLT) == BOLT or is_sfc(file) then
    return out, "sfc"
  end

  return out, "none"
end

--- Move to another file of the Livewire component under the cursor.
function M.toggle()
  local laravel = require("artisan")
  local root = laravel.root()
  if not root then
    return vim.notify("Not in a Laravel project (no artisan found)", vim.log.levels.WARN)
  end

  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
  root = vim.fs.normalize(root)

  local related, kind = M.related(root, file)

  if #related == 1 then
    return vim.cmd.edit(vim.fn.fnameescape(related[1].path))
  end
  if #related > 1 then
    return vim.ui.select(related, {
      prompt = "Livewire component",
      format_item = function(item)
        return ("%-12s %s"):format(item.label, vim.fn.fnamemodify(item.path, ":."))
      end,
    }, function(choice)
      if choice then vim.cmd.edit(vim.fn.fnameescape(choice.path)) end
    end)
  end

  -- Nothing to move to: say which of the three shapes this is, because
  -- "single-file component" and "not a component at all" are very different
  -- answers to the same keypress.
  if kind == "sfc" then
    return vim.notify("Single-file Livewire component — class and view are both in this file", vim.log.levels.INFO)
  end
  if kind == "class" then
    return vim.notify("Livewire class with no view on disk yet", vim.log.levels.WARN)
  end
  if kind == "view" then
    return vim.notify("Livewire view with no class on disk (single-file/Volt component?)", vim.log.levels.INFO)
  end
  return vim.notify("Not a Livewire component", vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Component discovery: `<livewire:…>` and `<x-…>` tag names, and the files they
-- point at.
--
-- blade-nav owns this upstream but predates Livewire 4 and gets it wrong both
-- ways: it scans only `resources/views/livewire` for Livewire components (so it
-- found 1 of the 4 in a stock Livewire 4 app) while scanning ALL of
-- `resources/views/components` for Blade components (so it offered literal
-- `<x-admin.⚡user-table />`, which is not a valid tag). Both handlers are
-- disabled in lua/plugins/laravel.lua and answered here instead.
-- ---------------------------------------------------------------------------

--- `resources/views/components/billing/⚡invoice/invoice.blade.php` → `billing.invoice`
--- `resources/views/components/admin/⚡user-table.blade.php`        → `admin.user-table`
---@param segments string[] path segments below resources/views/components
---@return string
local function dotted(segments)
  return table.concat(segments, ".")
end

local function strip_bolt(s)
  return s:sub(1, #BOLT) == BOLT and s:sub(#BOLT + 1) or s
end

--- Every component in the project, split by which tag syntax renders it.
--- Cheap enough to run per completion request (one directory walk, capped
--- depth), and always current — no cache to invalidate when a file is added.
---@param root string
---@return { livewire: {name: string, path: string}[], blade: {name: string, path: string}[] }
function M.components(root)
  local livewire, blade = {}, {}

  local comp_root = root .. "/" .. COMPONENT_DIR
  if vim.uv.fs_stat(comp_root) then
    for path, kind in vim.fs.dir(comp_root, { depth = 8 }) do
      if kind == "file" and path:match("%.blade%.php$") then
        local segments = vim.split(path:gsub("%.blade%.php$", ""), "/", { plain = true })
        local file = segments[#segments]
        local parent = segments[#segments - 1]
        local abs = comp_root .. "/" .. path

        if parent and parent:sub(1, #BOLT) == BOLT then
          -- mfc: the directory is the component, the file inside repeats its name
          local dir_segments = { unpack(segments, 1, #segments - 1) }
          dir_segments[#dir_segments] = strip_bolt(parent)
          livewire[#livewire + 1] = { name = dotted(dir_segments), path = abs }
        elseif file:sub(1, #BOLT) == BOLT then
          segments[#segments] = strip_bolt(file)
          livewire[#livewire + 1] = { name = dotted(segments), path = abs }
        elseif is_sfc(abs) then
          -- sfc generated with --emoji=false: only the contents give it away
          livewire[#livewire + 1] = { name = dotted(segments), path = abs }
        else
          blade[#blade + 1] = { name = dotted(segments), path = abs }
        end
      end
    end
  end

  -- Legacy class-based Livewire components.
  for _, dir in ipairs(CLASS_DIRS) do
    local class_root = root .. "/" .. dir
    if vim.uv.fs_stat(class_root) then
      for path, kind in vim.fs.dir(class_root, { depth = 8 }) do
        if kind == "file" and path:match("%.php$") then
          local segments = {}
          for part in path:gsub("%.php$", ""):gmatch("[^/]+") do
            segments[#segments + 1] = kebab(part)
          end
          livewire[#livewire + 1] = { name = dotted(segments), path = class_root .. "/" .. path }
        end
      end
    end
  end

  -- Class-backed Blade components (app/View/Components/Foo.php → <x-foo />).
  local view_components = root .. "/app/View/Components"
  if vim.uv.fs_stat(view_components) then
    for path, kind in vim.fs.dir(view_components, { depth = 8 }) do
      if kind == "file" and path:match("%.php$") then
        local segments = {}
        for part in path:gsub("%.php$", ""):gmatch("[^/]+") do
          segments[#segments + 1] = kebab(part)
        end
        blade[#blade + 1] = { name = dotted(segments), path = view_components .. "/" .. path }
      end
    end
  end

  return { livewire = livewire, blade = blade }
end

--- The tag the cursor sits inside, if any.
---@return "livewire"|"blade"|nil kind
---@return string|nil name
function M.tag_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Scan every candidate on the line and keep the one spanning the cursor.
  for _, spec in ipairs({
    { kind = "livewire", pattern = "<livewire:([%w%.%-_]+)" },
    { kind = "livewire", pattern = "@livewire%(%s*['\"]([%w%.%-_]+)['\"]" },
    { kind = "blade", pattern = "<x%-([%w%.%-_]+)" },
  }) do
    local init = 1
    while true do
      local s, e, name = line:find(spec.pattern, init)
      if not s then break end
      if col >= s and col <= e + 1 then return spec.kind, name end
      init = e + 1
    end
  end
  return nil, nil
end

--- Resolve the component tag under the cursor to a file. Returns false when the
--- cursor is not on a tag, so a `gf` chain can fall through to the next handler.
---@return boolean handled
function M.goto_component()
  local kind, name = M.tag_at_cursor()
  if not kind then return false end

  local root = require("artisan").root()
  if not root then return false end

  for _, component in ipairs(M.components(root)[kind]) do
    if component.name == name then
      vim.cmd.edit(vim.fn.fnameescape(component.path))
      return true
    end
  end

  vim.notify(("No %s component named '%s'"):format(kind, name), vim.log.levels.WARN)
  return true
end

function M.setup()
  vim.api.nvim_create_user_command("LivewireToggle", M.toggle, {
    desc = "Livewire: move to another file of this component (class/view/js/css)",
  })
  vim.keymap.set("n", "<leader>lw", M.toggle, { desc = "Livewire: component files" })
end

return M
