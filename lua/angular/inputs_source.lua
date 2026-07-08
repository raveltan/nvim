-- blink.cmp source: @Input/@Output completion for Angular inline-template
-- component tags. When the cursor is inside a `<app-foo …>` start tag, this
-- offers that component's inputs/outputs (name + type). All resolution and
-- caching lives in require("angular").component_inputs; this file only shapes
-- the results into blink completion items.
--
-- Wired in lua/plugins/lsp.lua as provider `angular_inputs`, prepended to the
-- typescript source list. See lua/angular/init.lua for the data side.
local kinds = vim.lsp.protocol.CompletionItemKind
local Snippet = vim.lsp.protocol.InsertTextFormat.Snippet

local M = {}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:enabled()
  return vim.bo.filetype == "typescript"
end

-- `[` / `(` are the Angular binding brackets -- the natural trigger. Letters are
-- covered by blink's show_on_keyword, so we deliberately omit space (it would
-- pop the menu after every space in a TS file).
function M:get_trigger_characters()
  return { "[", "(", "." }
end

-- The binding to insert, brackets included, with `inner` as the value (a snippet
-- tab-stop by default). Outputs use (), two-way models use [()], else [].
local function binding(kind, name, inner)
  if kind == "output" then
    return "(" .. name .. ')="' .. inner .. '"'
  elseif kind == "model" then
    return "[(" .. name .. ')]="' .. inner .. '"'
  end
  return "[" .. name .. ']="' .. inner .. '"'
end

-- Readable one-line signature for the docs popup.
local function signature(it)
  local ty = it.type and (": " .. it.type) or ""
  local alias = it.name ~= it.prop and ("  (as [" .. it.name .. "])") or ""
  if it.kind == "output" then
    return "@Output() " .. it.prop .. (it.type and (": EventEmitter<" .. it.type .. ">") or "") .. alias
  elseif it.kind == "model" then
    return it.prop .. " = model<" .. (it.type or "?") .. ">()" .. alias
  end
  return "@Input() " .. it.prop .. ty .. alias
end

-- Docs popup body: the signature, then the member's own doc comment (the JSDoc
-- or `//` note above it), then where it comes from. `extra` (enum info) is
-- appended by resolve.
local function doc_value(it, meta, extra)
  local parts = { "```typescript", signature(it), "```" }
  if it.doc and it.doc ~= "" then
    parts[#parts + 1] = ""
    parts[#parts + 1] = it.doc
  end
  parts[#parts + 1] = ""
  parts[#parts + 1] = "`" .. meta.tag .. "` — " .. vim.fn.fnamemodify(meta.file, ":t")
  if extra then parts[#parts + 1] = extra end
  return table.concat(parts, "\n")
end

local function kind_icon(it)
  if it.kind == "output" then return kinds.Event end
  if it.kind == "model" then return kinds.Reference end
  return kinds.Property
end

function M:get_completions(ctx, callback)
  callback = vim.schedule_wrap(callback)
  local empty = { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
  local row = ctx.cursor[1] - 1
  local ng = require("angular")

  -- 1. Enum-member completion: cursor after `SomeEnum.` inside a template.
  ng.template_enum_members(function(members, enum, en)
    if members then
      -- Replace the partial member typed after the dot.
      local dot = ctx.line:sub(1, ctx.cursor[2]):match(".*()%.")
      local edits = {}
      local imp = ng.build_import_edit(0, enum, en.spec, en.file)
      if imp then edits[#edits + 1] = imp end
      local fld = ng.build_enum_field_edit(0, enum)
      if fld then edits[#edits + 1] = fld end
      local items = {}
      for i, m in ipairs(members) do
        items[i] = {
          label = m,
          filterText = m,
          sortText = string.format("%03d", i),
          kind = kinds.EnumMember,
          labelDetails = { description = enum },
          insertText = m,
          textEdit = {
            newText = m,
            range = {
              start = { line = row, character = dot }, -- 0-indexed col just after `.`
              ["end"] = { line = row, character = ctx.cursor[2] },
            },
          },
          documentation = { kind = "markdown", value = "`" .. enum .. "." .. m .. "`" },
          additionalTextEdits = #edits > 0 and edits or nil,
        }
      end
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
    end

    -- 2. Attribute-VALUE completion: by the input's declared type — enum members
    -- (`ButtonSize.SMALL`, incl. nullable `Enum | null`) or string/number-literal
    -- union values (`'abc'`), when the cursor is inside `[attr]="▏"`.
    ng.template_value_completions(function(spec)
      if spec then
        local items = {}
        if spec.kind == "enum" then
          local edits = {}
          local imp = ng.build_import_edit(0, spec.enum, spec.en.spec, spec.en.file)
          if imp then edits[#edits + 1] = imp end
          local fld = ng.build_enum_field_edit(0, spec.enum)
          if fld then edits[#edits + 1] = fld end
          for i, m in ipairs(spec.en.members) do
            local full = spec.enum .. "." .. m
            items[i] = {
              label = full,
              filterText = full,
              sortText = string.format("%03d", i),
              kind = kinds.EnumMember,
              labelDetails = { description = spec.enum },
              insertText = full,
              additionalTextEdits = #edits > 0 and edits or nil,
              documentation = { kind = "markdown", value = "`" .. full .. "`" },
            }
          end
        else -- string/number literal union
          local ks = ctx.bounds.start_col
          local before1 = ks > 1 and ctx.line:sub(ks - 1, ks - 1) or ""
          for i, v in ipairs(spec.values) do
            local inner = v:gsub("^['\"]", ""):gsub("['\"]$", "")
            local shown = spec.is_binding and v or inner
            -- Binding value uses `'literal'`; if the user already typed the inner
            -- quote, don't repeat it.
            if spec.is_binding and before1 == "'" then shown = shown:sub(2) end
            items[i] = {
              label = spec.is_binding and v or inner,
              filterText = inner,
              sortText = string.format("%03d", i),
              kind = kinds.Value,
              insertText = shown,
            }
          end
        end
        return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
      end

      -- 3. Attribute-name completion: the component's @Input/@Output list.
      ng.component_inputs(function(inputs, meta)
        if not inputs or #inputs == 0 then return callback(empty) end

    -- Replace the typed keyword, extended left to swallow an already-typed
    -- binding bracket so the snippet's own brackets never double up.
    local line, ks = ctx.line, ctx.bounds.start_col -- ks: 1-indexed keyword start
    local before1 = ks > 1 and line:sub(ks - 1, ks - 1) or ""
    local before2 = ks > 2 and line:sub(ks - 2, ks - 2) or ""
    local extend = 0
    if before1 == "[" or before1 == "(" or before1 == "*" or before1 == "#" then
      extend = (before1 == "(" and before2 == "[") and 2 or 1 -- banana `[(`
    end
    local start_char = (ks - 1) - extend -- 0-indexed
    local end_char = ctx.cursor[2]       -- 0-indexed

    local items = {}
    for _, it in ipairs(inputs) do
      local text = binding(it.kind, it.name, "$1")
      local docbase = doc_value(it, meta)
      items[#items + 1] = {
        label = it.name,
        filterText = it.name,
        sortText = it.name,
        kind = kind_icon(it),
        labelDetails = { description = it.type or it.kind },
        insertText = text,
        insertTextFormat = Snippet,
        textEdit = {
          newText = text,
          range = {
            start = { line = row, character = start_char },
            ["end"] = { line = row, character = end_char },
          },
        },
        documentation = { kind = "markdown", value = docbase },
        -- Round-tripped to resolve() to seed enum values + auto-import.
        data = { name = it.name, prop = it.prop, kind = it.kind, type = it.type, doc = it.doc, docbase = docbase },
      }
    end
      callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
      end)
    end)
  end)
end

-- Enrich the focused item when its input type is an exported enum: seed the
-- binding value with `Enum.` and, on accept, import the enum into this buffer.
-- Outputs are event handlers, not enum values, so they're left untouched.
function M:resolve(item, callback)
  callback = vim.schedule_wrap(callback)
  local d = item.data
  if not d or not d.type or d.kind == "output" then return callback(item) end

  require("angular").resolve_enum(d.type, function(en)
    if not en then return callback(item) end
    local name = en.name -- normalized enum name (d.type may be `Enum | null`)

    local extra = { "", "**enum " .. name .. "**" }
    if en.spec then extra[#extra + 1] = "→ `import { " .. name .. " } from '" .. en.spec .. "'`" end
    if #en.members > 0 then
      local shown = {}
      for i = 1, math.min(#en.members, 12) do
        shown[i] = "`" .. name .. "." .. en.members[i] .. "`"
      end
      extra[#extra + 1] = table.concat(shown, " · ") .. (#en.members > 12 and " …" or "")
    end

    local resolved = {
      -- range is preserved from the original item by blink's deep-merge.
      textEdit = { newText = binding(d.kind, d.name, name .. ".$1") },
      documentation = { kind = "markdown", value = d.docbase .. "\n" .. table.concat(extra, "\n") },
    }
    -- On accept: import the enum AND expose it on the class (`Enum = Enum;`), so
    -- the seeded `Enum.MEMBER` actually resolves in the template.
    local ng = require("angular")
    local edits = {}
    local imp = ng.build_import_edit(0, name, en.spec, en.file)
    if imp then edits[#edits + 1] = imp end
    local fld = ng.build_enum_field_edit(0, name)
    if fld then edits[#edits + 1] = fld end
    if #edits > 0 then resolved.additionalTextEdits = edits end
    callback(resolved)
  end)
end

return M
