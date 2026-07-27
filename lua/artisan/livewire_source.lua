-- blink.cmp source: `wire:` and Alpine `x-` attribute names in blade buffers.
--
-- Nothing else in the stack offers these. blade-nav completes component *tags*
-- (`<livewire:`, `<x-`) and laravel.nvim completes the *strings* inside
-- view()/route()/config(); the attributes themselves are invisible to both, and
-- to the html LSP, which only knows standard HTML.
--
-- Wired in lua/plugins/lsp.lua as provider `livewire`, prepended to the blade
-- source list. Class/view navigation lives in lua/artisan/livewire.lua.
local kinds = vim.lsp.protocol.CompletionItemKind
local Snippet = vim.lsp.protocol.InsertTextFormat.Snippet

local M = {}

-- `value = false` means the attribute is a bare flag (`wire:ignore`), so it is
-- inserted without `="…"`. `mods` are the dot-modifiers offered once the user
-- types the trailing dot.
local ATTRIBUTES = {
  -- Livewire: data binding
  { name = "wire:model", doc = "Two-way bind an input to a component property.", value = true,
    mods = { "live", "blur", "change", "lazy", "debounce.500ms", "throttle.500ms", "number", "boolean", "fill" } },

  -- Livewire: actions
  { name = "wire:click", doc = "Call a component method on click.", value = true,
    mods = { "prevent", "stop", "self", "debounce.500ms", "throttle.500ms" } },
  { name = "wire:submit", doc = "Call a component method on form submit (prevents default by default in v3).", value = true,
    mods = { "prevent" } },
  { name = "wire:change", doc = "Call a component method on change.", value = true },
  { name = "wire:input", doc = "Call a component method on input.", value = true },
  { name = "wire:blur", doc = "Call a component method on blur.", value = true },
  { name = "wire:focus", doc = "Call a component method on focus.", value = true },
  { name = "wire:keydown", doc = "Call a component method on keydown.", value = true,
    mods = { "enter", "escape", "tab", "space", "arrow-up", "arrow-down", "prevent", "stop" } },
  { name = "wire:keyup", doc = "Call a component method on keyup.", value = true,
    mods = { "enter", "escape", "tab", "space", "arrow-up", "arrow-down", "prevent", "stop" } },
  { name = "wire:mouseenter", doc = "Call a component method on mouseenter.", value = true },
  { name = "wire:confirm", doc = "Confirmation dialog before the action runs.", value = true },

  -- Livewire: loading / lifecycle state
  { name = "wire:loading", doc = "Show this element only while a request is in flight.", value = false,
    mods = { "delay", "delay.shortest", "delay.shorter", "delay.short", "delay.long", "delay.longer",
             "delay.longest", "remove", "class", "class.remove", "attr" } },
  { name = "wire:target", doc = "Scope wire:loading/wire:dirty to specific actions or properties.", value = true },
  { name = "wire:dirty", doc = "Show this element only while the bound value differs from the server.", value = false,
    mods = { "remove", "class", "class.remove", "attr" } },
  { name = "wire:offline", doc = "Show this element only while the browser is offline.", value = false,
    mods = { "remove", "class", "class.remove", "attr" } },

  -- Livewire: polling & lifecycle hooks
  { name = "wire:poll", doc = "Re-render on an interval.", value = false,
    mods = { "5s", "10s", "30s", "keep-alive", "visible" } },
  { name = "wire:init", doc = "Call a component method as soon as the component renders.", value = true },
  { name = "wire:stream", doc = "Target for streamed content from stream().", value = true },

  -- Livewire: DOM control
  { name = "wire:key", doc = "Stable identity for an element inside a loop — required for correct diffing.", value = true },
  { name = "wire:ignore", doc = "Exclude this element's subtree from DOM diffing (wrap third-party JS).", value = false,
    mods = { "self" } },
  { name = "wire:replace", doc = "Replace this element's children instead of diffing them.", value = false,
    mods = { "self" } },
  { name = "wire:transition", doc = "Animate the element in/out across a re-render.", value = false },
  { name = "wire:show", doc = "Toggle display based on a component expression.", value = true },
  { name = "wire:text", doc = "Bind the element's text content to a component property.", value = true },
  { name = "wire:cloak", doc = "Hide the element until Livewire has initialised.", value = false },
  { name = "wire:ref", doc = "Name this element so JS can reach it via $wire.$refs.", value = true },

  -- Livewire: navigation (SPA mode)
  { name = "wire:navigate", doc = "Intercept the link and swap the page without a full reload.", value = false,
    mods = { "hover" } },
  { name = "wire:current", doc = "Class(es) to apply when this link matches the current URL.", value = true },

  -- Alpine core
  { name = "x-data", doc = "Declare a new Alpine component and its reactive state.", value = true },
  { name = "x-init", doc = "Run an expression when the element initialises.", value = true },
  { name = "x-show", doc = "Toggle display based on an expression.", value = true },
  { name = "x-bind:", doc = "Bind an attribute to an expression (shorthand `:attr`).", value = true },
  { name = "x-on:", doc = "Listen for a DOM event (shorthand `@event`).", value = true },
  { name = "x-text", doc = "Set the element's text content from an expression.", value = true },
  { name = "x-html", doc = "Set the element's innerHTML from an expression.", value = true },
  { name = "x-model", doc = "Two-way bind an input to Alpine state.", value = true,
    mods = { "lazy", "number", "debounce.500ms", "throttle.500ms", "fill" } },
  { name = "x-modelable", doc = "Expose a local Alpine property for x-model binding by a parent.", value = true },
  { name = "x-for", doc = "Render a template once per item.", value = true },
  { name = "x-if", doc = "Conditionally render a <template> block.", value = true },
  { name = "x-effect", doc = "Re-run an expression whenever its dependencies change.", value = true },
  { name = "x-ref", doc = "Name this element so it is reachable via $refs.", value = true },
  { name = "x-teleport", doc = "Move a <template>'s content elsewhere in the DOM.", value = true },
  { name = "x-transition", doc = "Animate the element in and out.", value = false,
    mods = { "duration.300ms", "delay.100ms", "opacity", "scale.90", "enter", "leave" } },
  { name = "x-ignore", doc = "Stop Alpine from initialising this subtree.", value = false },
  { name = "x-cloak", doc = "Hide the element until Alpine has initialised.", value = false },
  { name = "x-id", doc = "Scope generated ids for $id().", value = true },
}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:enabled()
  return vim.bo.filetype == "blade"
end

-- `:` `-` `.` build the attribute names, `<` opens a component tag, `$` and `>`
-- (as in `$this->`) open template member completion. Bare letters are already
-- covered by blink's show_on_keyword.
function M:get_trigger_characters()
  return { ":", "-", ".", "<", "$", ">", '"' }
end

-- blink's keyword bounds stop at `:` and `-`, so the typed text has to be
-- recovered by hand: walk left over the attribute character set to find where
-- the token really started. Everything is inserted with an explicit textEdit
-- over that range so `wire:mod<Tab>` replaces `wire:mod`, not just `mod`.
local ATTR_CHARS = "[%w:%.%-]"

local function token_start(line, cursor_col)
  local i = cursor_col
  while i > 0 and line:sub(i, i):match(ATTR_CHARS) do
    i = i - 1
  end
  return i -- 0-indexed column of the token start
end

local function item(attr, row, start_char, end_char)
  local text = attr.value and (attr.name .. '="$1"') or attr.name
  -- x-bind:/x-on: take the event or attribute name first.
  if attr.name:sub(-1) == ":" then text = attr.name .. '$1="$2"' end
  return {
    label = attr.name,
    filterText = attr.name,
    sortText = attr.name,
    kind = kinds.Property,
    labelDetails = { description = attr.name:match("^wire:") and "livewire" or "alpine" },
    insertText = text,
    insertTextFormat = Snippet,
    textEdit = {
      newText = text,
      range = {
        start = { line = row, character = start_char },
        ["end"] = { line = row, character = end_char },
      },
    },
    documentation = { kind = "markdown", value = "`" .. attr.name .. "`\n\n" .. attr.doc },
  }
end

local function modifier_item(base, mod, row, start_char, end_char)
  local full = base .. "." .. mod
  return {
    label = full,
    filterText = full,
    sortText = full,
    kind = kinds.EnumMember,
    labelDetails = { description = "modifier" },
    insertText = full,
    textEdit = {
      newText = full,
      range = {
        start = { line = row, character = start_char },
        ["end"] = { line = row, character = end_char },
      },
    },
    documentation = { kind = "markdown", value = "`" .. full .. "`" },
  }
end

-- Component-tag completion. blade-nav's equivalents are disabled (see
-- lua/plugins/laravel.lua): on Livewire 4 they miss most components and emit
-- literal-⚡ tags. `<livewire:` and `<x-` are answered from the same shape logic
-- that drives <leader>lw, so all three component layouts are covered.
local function component_items(prefix, row, start_char, end_char)
  local root = require("artisan").root()
  if not root then return nil end

  local kind = prefix:match("^<livewire:") and "livewire" or (prefix:match("^<x%-") and "blade" or nil)
  if not kind then return nil end

  local lead = kind == "livewire" and "<livewire:" or "<x-"
  local items = {}
  for _, component in ipairs(require("artisan.livewire").components(root)[kind]) do
    local text = lead .. component.name
    items[#items + 1] = {
      label = text,
      filterText = text,
      sortText = component.name,
      kind = kinds.Class,
      labelDetails = { description = vim.fn.fnamemodify(component.path, ":.") },
      insertText = text,
      textEdit = {
        newText = text,
        range = {
          start = { line = row, character = start_char },
          ["end"] = { line = row, character = end_char },
        },
      },
      documentation = { kind = "markdown", value = "`" .. text .. "`\n\n" .. component.path },
    }
  end
  return items
end

-- ---------------------------------------------------------------------------
-- Component-aware completion: the props a tag accepts, and the properties and
-- actions the current component exposes to wire: values. This is the Livewire
-- counterpart of the Angular @Input source in lua/angular/inputs_source.lua.
-- ---------------------------------------------------------------------------

--- The component tag the cursor sits *inside* (after the name, before `>`).
--- Scans back a few lines because multi-attribute tags are routinely wrapped.
---@return "livewire"|"blade"|nil kind
---@return string|nil name
local function enclosing_tag()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local first = math.max(1, row - 10)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, row, false)
  if #lines == 0 then return nil end
  lines[#lines] = lines[#lines]:sub(1, col)
  local text = table.concat(lines, "\n")

  -- Last tag opener before the cursor wins; if a `>` follows it, the tag is
  -- already closed and the cursor is in body text, not in the attribute list.
  local kind, name, at
  for s, tag in text:gmatch("()<(livewire:[%w%.%-_]+)") do
    at, kind, name = s, "livewire", tag:sub(#"livewire:" + 1)
  end
  for s, tag in text:gmatch("()<(x%-[%w%.%-_]+)") do
    if not at or s > at then
      at, kind, name = s, "blade", tag:sub(3)
    end
  end
  if not at then return nil end
  if text:find("[>]", at) then return nil end
  return kind, name
end

--- Resolve a tag name to its component file.
---@return string|nil
local function component_path(kind, name)
  local root = require("artisan").root()
  if not root then return nil end
  for _, component in ipairs(require("artisan.livewire").components(root)[kind]) do
    if component.name == name then return component.path end
  end
  return nil
end

local function signature(prop)
  local parts = {}
  if prop.type then parts[#parts + 1] = prop.type end
  parts[#parts + 1] = "$" .. prop.name
  local sig = table.concat(parts, " ")
  if prop.default then sig = sig .. " = " .. prop.default end
  return sig
end

--- Props of the tag under the cursor, as attributes to insert.
--- `:name="…"` when the user already typed the binding colon, else `name="…"`.
local function prop_items(kind, name, row, start_char, end_char, bound)
  local path = component_path(kind, name)
  if not path then return nil end
  local parsed = require("artisan.props").for_file(path)
  if #parsed.props == 0 then return nil end

  local items = {}
  for _, prop in ipairs(parsed.props) do
    local attr = (bound and ":" or "") .. prop.name
    local text = attr .. '="$1"'
    local doc = { "```php", signature(prop), "```" }
    if prop.doc then
      doc[#doc + 1] = ""
      doc[#doc + 1] = prop.doc
    end
    doc[#doc + 1] = ""
    doc[#doc + 1] = ("`<%s%s>` — %s"):format(kind == "livewire" and "livewire:" or "x-", name,
      vim.fn.fnamemodify(path, ":."))
    items[#items + 1] = {
      label = attr,
      filterText = prop.name,
      sortText = "0" .. prop.name, -- props before the generic wire:/x- list
      kind = kinds.Property,
      labelDetails = { description = prop.type or (prop.from == "mount" and "mount()" or "prop") },
      insertText = text,
      insertTextFormat = Snippet,
      textEdit = {
        newText = text,
        range = {
          start = { line = row, character = start_char },
          ["end"] = { line = row, character = end_char },
        },
      },
      documentation = { kind = "markdown", value = table.concat(doc, "\n") },
    }
  end
  return items
end

--- Values for `wire:model="…"` (the current component's properties) and
--- `wire:click="…"` / `wire:submit="…"` (its public methods).
---@return table[]|nil
local PROPERTY_DIRECTIVES = {
  ["wire:model"] = true, ["wire:text"] = true, ["wire:show"] = true,
}
local ACTION_DIRECTIVES = {
  ["wire:click"] = true, ["wire:submit"] = true, ["wire:change"] = true,
  ["wire:keydown"] = true, ["wire:keyup"] = true, ["wire:init"] = true,
  ["wire:blur"] = true, ["wire:focus"] = true, ["wire:confirm"] = false,
}

local function wire_value_items(line, col, row)
  -- Cursor inside an unterminated double-quoted value of a wire: directive.
  -- `typed` is what has been written since the opening quote, which is exactly
  -- the range the textEdit must replace.
  local attr, typed = line:sub(1, col):match('(wire:[%w%.%-]+)="([^"]*)$')
  if not attr then return nil end

  local base = attr:match("^(wire:%w+)")
  local parsed = require("artisan.props").for_current_component(0)

  local pool, label
  if PROPERTY_DIRECTIVES[base] then
    pool, label = parsed.props, "property"
  elseif ACTION_DIRECTIVES[base] then
    pool, label = parsed.methods, "action"
  elseif base == "wire:target" then
    -- wire:target names either, since it scopes loading state to whatever is
    -- in flight.
    pool = vim.list_extend(vim.deepcopy(parsed.methods), parsed.props)
    label = "target"
  end
  if not pool or #pool == 0 then return nil end

  local start_char = col - #typed
  local items = {}
  for _, entry in ipairs(pool) do
    items[#items + 1] = {
      label = entry.name,
      filterText = entry.name,
      sortText = entry.name,
      kind = entry.from == "method" and kinds.Method or kinds.Property,
      labelDetails = { description = entry.type or label },
      insertText = entry.name,
      textEdit = {
        newText = entry.name,
        range = {
          start = { line = row, character = start_char },
          ["end"] = { line = row, character = col },
        },
      },
      documentation = {
        kind = "markdown",
        value = "```php\n"
          .. (entry.from == "method" and (entry.name .. "()") or signature(entry))
          .. "\n```"
          .. (entry.doc and ("\n\n" .. entry.doc) or ""),
      },
    }
  end
  return items
end

--- `$title`, `$perPage`, … inside a component's OWN template, plus
--- `$this->method()`. intelephense is not attached to blade (it cannot parse
--- @directives), so without this nothing at all completes after `$` in a view —
--- the blade equivalent of losing template member completion in Angular.
---@return table[]|nil
local function template_variable_items(line, col, row)
  -- `$` starts the token; `->` continues it for the `$this->` case.
  local start = col
  while start > 0 and line:sub(start, start):match("[%w_]") do
    start = start - 1
  end

  local this_call = line:sub(1, col):match("%$this%->([%w_]*)$")
  local sigil = line:sub(start, start) == "$"
  if not this_call and not sigil then return nil end

  local parsed = require("artisan.props").for_current_component(0)
  local pool, replace_from
  if this_call then
    pool = vim.list_extend(vim.deepcopy(parsed.methods), parsed.props)
    replace_from = col - #this_call
  else
    pool = parsed.props
    replace_from = start - 1 -- 0-indexed, includes the `$`
  end
  if #pool == 0 then return nil end

  local items = {}
  for _, entry in ipairs(pool) do
    local text = this_call and (entry.from == "method" and (entry.name .. "()") or entry.name)
      or ("$" .. entry.name)
    items[#items + 1] = {
      label = text,
      filterText = text,
      sortText = entry.name,
      kind = entry.from == "method" and kinds.Method or kinds.Property,
      labelDetails = { description = entry.type or (entry.from == "method" and "action" or "prop") },
      insertText = text,
      textEdit = {
        newText = text,
        range = {
          start = { line = row, character = replace_from },
          ["end"] = { line = row, character = col },
        },
      },
      documentation = {
        kind = "markdown",
        value = "```php\n"
          .. (entry.from == "method" and (entry.name .. "()") or signature(entry))
          .. "\n```"
          .. (entry.doc and ("\n\n" .. entry.doc) or ""),
      },
    }
  end
  return items
end

-- Component tags start with `<`, which is not in the attribute character set.
local function tag_start(line, cursor_col)
  local i = cursor_col
  while i > 0 and line:sub(i, i):match("[%w:%.%-<]") do
    if line:sub(i, i) == "<" then return i - 1 end
    i = i - 1
  end
  return nil
end

function M:get_completions(ctx, callback)
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]

  -- 1. `wire:model="…"` / `wire:click="…"` values — the enclosing component's
  --    own properties and actions. Checked first: the cursor is inside quotes,
  --    where neither a tag name nor an attribute name can appear.
  local values = wire_value_items(ctx.line, col, row)
  if values then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = values })
  end

  -- 2. `$prop` / `$this->action()` in the component's own template.
  local vars = template_variable_items(ctx.line, col, row)
  if vars then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = vars })
  end

  -- 3. `<livewire:…` / `<x-…` tag names.
  local tag_col = tag_start(ctx.line, col)
  if tag_col then
    local items = component_items(ctx.line:sub(tag_col + 1, col), row, tag_col, col)
    if items and #items > 0 then
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
    end
  end

  local start_char = token_start(ctx.line, col)
  local typed = ctx.line:sub(start_char + 1, col)

  local items = {}

  -- 4. Inside a component's attribute list: that component's own props come
  --    first, then the generic wire:/x- attributes below.
  local kind, name = enclosing_tag()
  if kind and not typed:find("^wire:") and not typed:find("^x%-") then
    -- `:` is part of the attribute token, so a leading one is the first
    -- character of `typed`, not the character before it. It means "bind a PHP
    -- expression"; the replacement range already covers it, so the inserted
    -- text carries the colon rather than doubling it.
    local bound = typed:sub(1, 1) == ":"
    local props = prop_items(kind, name, row, start_char, col, bound)
    if props then vim.list_extend(items, props) end
  end

  -- Inside `wire:model.` / `x-transition.` → offer that attribute's modifiers
  -- instead of the whole attribute list.
  -- 5. `wire:model.` / `x-transition.` → that directive's modifiers, and
  --    nothing else: the user has committed to a directive already.
  local base = typed:match("^([%w:%-]+)%.")
  local modifiers = false
  if base then
    for _, attr in ipairs(ATTRIBUTES) do
      if attr.name == base and attr.mods then
        for _, mod in ipairs(attr.mods) do
          items[#items + 1] = modifier_item(base, mod, row, start_char, col)
        end
        modifiers = true
        break
      end
    end
  end

  -- 6. The generic wire:/x- attribute list, appended after any component props
  --    rather than replacing them — inside a component tag both are valid.
  if not modifiers then
    for _, attr in ipairs(ATTRIBUTES) do
      items[#items + 1] = item(attr, row, start_char, col)
    end
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return M
