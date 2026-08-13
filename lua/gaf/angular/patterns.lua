-- rg patterns for the declarations the lookups chase, kept together so the regex
-- dialect (rg, not Lua) lives in one file.
local rx = require("gaf.angular.search").rx

local M = {}

-- Exact selector definition: the tag is a whole token, never `x-app-foo` or
-- `app-foo-bar`. Sole value, or a delimited member of a comma list.
function M.selector(sel)
  sel = rx(sel)
  return {
    "selector:\\s*['\"]\\s*" .. sel .. "\\s*['\"]",
    "selector:\\s*['\"][^'\"]*[\\s,\\[]" .. sel .. "[\\s,\\]'\"]",
  }
end

-- @Input/@Output/signal/host-binding named `name`.
function M.member(name)
  name = rx(name)
  return {
    "@Input\\([^)]*\\)\\s*(set\\s+|get\\s+)?" .. name .. "\\b", -- @Input(...) name / set name(
    "@Input\\(\\s*['\"]" .. name .. "['\"]",                    -- @Input('name') alias
    "@Output\\([^)]*\\)\\s*" .. name .. "\\b",
    "@Output\\(\\s*['\"]" .. name .. "['\"]",
    "@HostBinding\\(\\s*['\"][^'\"]*" .. name .. "\\b",
    "\\b" .. name .. "\\s*=\\s*(input|output|model)\\b", -- signal input()/output()/model()
  }
end

-- Attribute-selector directive: selector: '[name]'.
function M.directive(name)
  return { "selector:\\s*['\"][^'\"]*\\[" .. rx(name) .. "\\]" }
end

-- Type-like symbol referenced inside a template expression
-- (`[size]="ButtonSize.SMALL"` -> the `ButtonSize` enum/class/type/const).
function M.symbol_def(name)
  name = rx(name)
  return {
    "(export\\s+)?(declare\\s+)?(const\\s+)?enum\\s+" .. name .. "\\b",
    "(export\\s+)?(abstract\\s+)?class\\s+" .. name .. "\\b",
    "(export\\s+)?interface\\s+" .. name .. "\\b",
    "(export\\s+)?type\\s+" .. name .. "\\b",
    "(export\\s+)?(declare\\s+)?const\\s+" .. name .. "\\b",
    "(export\\s+)?function\\s+" .. name .. "\\b",
  }
end

-- Component-class member (`plainVar`, `onClick`) referenced in a template
-- expression. Anchored at line start so a template usage of the same name (in
-- the decorator above) is not mistaken for the declaration; the optional leading
-- decorator covers `@Input({ required: true }) foo$: Observable<...>`.
function M.member_decl(name)
  name = rx(name)
  local mods = "(readonly\\s+|private\\s+|public\\s+|protected\\s+|static\\s+|override\\s+|abstract\\s+|get\\s+|set\\s+|async\\s+)*"
  local decorator = "(@\\w+\\([^)]*\\)\\s*)?"
  return {
    "^\\s*" .. decorator .. mods .. name .. "\\s*[?!]?\\s*[:=(]",
    "^\\s*(public\\s+|private\\s+|protected\\s+|readonly\\s+)+" .. name .. "\\b",
  }
end

-- Free-text component lookup: a class whose name starts with `name` (so `Foo`
-- finds `FooComponent`) plus, when `name` looks like a selector, its definition.
function M.component(name)
  local pats = { "class\\s+" .. rx(name) }
  vim.list_extend(pats, M.selector(name))
  return pats
end

-- Exported enum / type alias, for value completion.
function M.exported_type(name)
  name = rx(name)
  return {
    "export\\s+(declare\\s+)?(const\\s+)?enum\\s+" .. name .. "\\b",
    "export\\s+type\\s+" .. name .. "\\b",
  }
end

-- Opening tag only, so each usage counts once. \b keeps `app-foo` off
-- `app-foobar` and skips closing tags and bare references.
function M.tag_usage(sel)
  return "<" .. rx(sel) .. "\\b"
end

return M
