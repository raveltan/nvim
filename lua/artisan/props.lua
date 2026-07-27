-- What a component accepts, and what it exposes.
--
-- The Livewire/Blade equivalent of lua/angular/inputs_source.lua's @Input
-- scraping: given a component file, return the attributes a caller may pass and
-- the actions a template may invoke, with types, defaults and doc comments so
-- the completion menu is worth reading.
--
-- Sources, by component shape:
--   anonymous Blade component  `@props(['label' => '', 'pill' => false])`
--   Livewire class / sfc / mfc  public properties, plus `mount()` parameters
--                               (Livewire binds those from the tag too)
--   actions                     public methods, minus Livewire's own lifecycle
--                               hooks — the targets for wire:click / wire:submit
--
-- Parsed with treesitter rather than patterns: `public ?int $teamId = null`,
-- promoted constructor properties and multi-property declarations are all
-- fiddly to match by hand, and the php parser is already installed.
local M = {}

-- Livewire calls these itself; offering them as wire:click targets is noise.
local LIFECYCLE = {
  mount = true, render = true, boot = true, booted = true, hydrate = true,
  dehydrate = true, updating = true, updated = true, rendering = true,
  rendered = true, exception = true, placeholder = true,
}

-- path -> { mtime = number, data = table }
local cache = {}

local function cached(path, build)
  local stat = vim.uv.fs_stat(path)
  if not stat then return nil end
  local key = stat.mtime.sec .. ":" .. stat.mtime.nsec .. ":" .. stat.size
  local hit = cache[path]
  if hit and hit.key == key then return hit.data end
  local data = build()
  cache[path] = { key = key, data = data }
  return data
end

--- Text of the `/** … */` comment immediately above `node`, cleaned of markers.
---@return string|nil
local function docblock(node, src)
  local prev = node:prev_named_sibling()
  if not prev or prev:type() ~= "comment" then return nil end
  local text = vim.treesitter.get_node_text(prev, src)
  if not text:match("^/%*%*") then return nil end
  local lines = {}
  for raw in text:gmatch("[^\n]+") do
    local line = raw:gsub("^%s*/?%*+/?", ""):gsub("%*/%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then lines[#lines + 1] = line end
  end
  local doc = table.concat(lines, " ")
  return doc ~= "" and doc or nil
end

--- The declared type of a property or parameter, as written.
---@return string|nil
local function type_of(node, src)
  for child in node:iter_children() do
    local t = child:type()
    if t == "primitive_type" or t == "named_type" or t == "optional_type" or t == "union_type" then
      return vim.treesitter.get_node_text(child, src)
    end
  end
  return nil
end

--- Public properties, mount() parameters and public methods of a PHP source.
---@param src string
---@return { props: table[], methods: table[] }
function M.parse_php(src)
  local props, methods = {}, {}
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "php")
  if not ok then return { props = props, methods = methods } end
  parser:parse(true)
  local root = parser:trees()[1]:root()

  local function visibility(node, src_)
    for child in node:iter_children() do
      if child:type() == "visibility_modifier" then
        return vim.treesitter.get_node_text(child, src_)
      end
    end
    -- No modifier at all means public in PHP.
    return "public"
  end

  local function walk(node)
    for child in node:iter_children() do
      local t = child:type()

      if t == "property_declaration" and visibility(child, src) == "public" then
        local doc = docblock(child, src)
        local declared = type_of(child, src)
        for element in child:iter_children() do
          if element:type() == "property_element" then
            local name, default
            for part in element:iter_children() do
              if part:type() == "variable_name" then
                name = vim.treesitter.get_node_text(part, src):gsub("^%$", "")
              elseif part:named() then
                default = vim.treesitter.get_node_text(part, src)
              end
            end
            if name then
              props[#props + 1] = {
                name = name,
                type = declared,
                default = default,
                doc = doc,
                from = "property",
                line = child:range() + 1, -- 1-based, for gd
              }
            end
          end
        end

      elseif t == "method_declaration" and visibility(child, src) == "public" then
        local name
        for part in child:iter_children() do
          if part:type() == "name" then
            name = vim.treesitter.get_node_text(part, src)
            break
          end
        end
        if name then
          -- Livewire binds mount() parameters from the component tag exactly
          -- like public properties, so they belong in the prop list.
          if name == "mount" then
            for part in child:iter_children() do
              if part:type() == "formal_parameters" then
                for param in part:iter_children() do
                  if param:type() == "simple_parameter" then
                    local pname, pdefault
                    for bit in param:iter_children() do
                      if bit:type() == "variable_name" then
                        pname = vim.treesitter.get_node_text(bit, src):gsub("^%$", "")
                      elseif bit:named() and bit:type():find("type") == nil then
                        pdefault = vim.treesitter.get_node_text(bit, src)
                      end
                    end
                    if pname then
                      props[#props + 1] = {
                        name = pname,
                        type = type_of(param, src),
                        default = pdefault,
                        doc = "mount() parameter",
                        from = "mount",
                        line = param:range() + 1,
                      }
                    end
                  end
                end
              end
            end
          elseif not LIFECYCLE[name] and not name:match("^__") then
            methods[#methods + 1] = {
              name = name,
              doc = docblock(child, src),
              from = "method",
              line = child:range() + 1,
            }
          end
        end
      end

      walk(child)
    end
  end

  walk(root)
  return { props = props, methods = methods }
end

--- `@props(['label' => '', 'tone' => 'gray', 'pill'])` from an anonymous Blade
--- component.
---
--- The blade grammar exposes the directive's argument list as a single
--- `parameter` node, so there is no array structure to walk in the blade tree.
--- Rather than split on commas — which breaks on any nested array or a comma
--- inside a default string — the argument text is re-parsed as PHP, giving the
--- same `array_element_initializer` tree the class path already walks.
---@param src string
---@return { props: table[], methods: table[] }
function M.parse_blade_props(src)
  local props = {}
  local body = src:match("@props%s*(%b())")
  if not body then return { props = props, methods = {} } end

  local php = "<?php " .. body:sub(2, -2) .. ";"
  local ok, parser = pcall(vim.treesitter.get_string_parser, php, "php")
  if not ok then return { props = props, methods = {} } end
  parser:parse(true)

  local function unquote(text)
    return (text:gsub("^['\"]", ""):gsub("['\"]$", ""))
  end

  local function walk(node)
    for child in node:iter_children() do
      if child:type() == "array_element_initializer" then
        local parts = {}
        for part in child:iter_children() do
          if part:named() then parts[#parts + 1] = part end
        end
        -- `'name' => default` has two children; a bare `'name'` has one.
        local name = parts[1] and unquote(vim.treesitter.get_node_text(parts[1], php))
        if name and name:match("^[%w_%-]+$") then
          props[#props + 1] = {
            name = name,
            default = parts[2] and vim.treesitter.get_node_text(parts[2], php) or nil,
            from = "props",
            -- The @props body was re-parsed standalone, so its rows do not map
            -- back to the blade file; gd locates the key by text instead.
            pattern = "['\"]" .. name .. "['\"]",
          }
        end
      elseif child:type() ~= "array_creation_expression" or node:type() == "expression_statement" then
        -- Only descend into the outermost array; nested ones are default values.
        walk(child)
      end
    end
  end

  walk(parser:trees()[1]:root())
  return { props = props, methods = {} }
end

--- Everything callers can pass to, or invoke on, the component at `path`.
---@param path string
---@return { props: table[], methods: table[] }
function M.for_file(path)
  local parsed = cached(path, function()
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then return { props = {}, methods = {} } end
    local src = table.concat(lines, "\n")

    -- A .blade.php file is either a Livewire single-file component (it opens
    -- with a PHP block) or an anonymous Blade component using @props.
    if path:match("%.blade%.php$") and not src:match("^%s*<%?php") then
      return M.parse_blade_props(src)
    end
    return M.parse_php(src)
  end) or { props = {}, methods = {} }

  -- Stamp the source path on each entry: gd needs to know which file to open,
  -- and callers routinely merge props from several components.
  for _, list in ipairs({ parsed.props, parsed.methods }) do
    for _, entry in ipairs(list) do entry.path = path end
  end
  return parsed
end

--- Props and actions of the component the cursor is currently editing — used
--- for `wire:model="…"` and `wire:click="…"` values, which bind to the
--- enclosing component, not to a child tag.
---@param bufnr integer|nil
---@return { props: table[], methods: table[] }
function M.for_current_component(bufnr)
  bufnr = bufnr or 0
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then return { props = {}, methods = {} } end

  -- An sfc/mfc view holds its own class; a class-based component keeps it in
  -- the sibling .php that <leader>lw jumps to.
  local root = require("artisan").root(vim.fs.dirname(file))
  if root then
    local related = require("artisan.livewire").related(vim.fs.normalize(root), vim.fs.normalize(file))
    for _, entry in ipairs(related) do
      if entry.path:match("%.php$") and not entry.path:match("%.blade%.php$") then
        return M.for_file(entry.path)
      end
    end
  end
  return M.for_file(file)
end

return M
