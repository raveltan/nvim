-- blink.cmp source: completion inside Angular inline templates. It offers the
-- component tags in scope (`<fl-bu` -> the whole `<fl-button>…</fl-button>`
-- element), a component's @Input/@Output names once the cursor is inside a
-- `<app-foo …>` start tag, and the values those inputs accept. All resolution
-- and caching lives in require("gaf.angular"); this file only shapes the results
-- into blink completion items.
--
-- Wired in lua/plugins/lsp.lua as provider `angular_inputs`, prepended to the
-- typescript source list. See lua/gaf/angular/init.lua for the data side.
--
-- Accepting a tag also makes it resolve. A standalone consumer takes an import
-- statement and an `imports: [ ]` entry in its own file, which resolve attaches as
-- additionalTextEdits; an NgModule-declared one needs that in the module DECLARING
-- it -- another file, which additionalTextEdits cannot reach (LSP defines them as
-- same-buffer) and so only M:execute can. `vim.g.angular_auto_wire`, read at accept
-- time so it can be flipped mid-session, says how far to go:
--   "all" (default) -- edit the owning @NgModule too, saving it if it was clean
--   "standalone"    -- this buffer's edits only, no second file
--   false           -- same as "standalone"
-- Anything else reads as "all": the NgModule case is 3837 of the webapp's 5209
-- components, so the useful default is the one that covers them.
local kinds = vim.lsp.protocol.CompletionItemKind
local Snippet = vim.lsp.protocol.InsertTextFormat.Snippet

local M = {}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:enabled()
  return vim.bo.filetype == "typescript"
end

-- `[` / `(` are the Angular binding brackets and `<` opens a tag -- the natural
-- triggers. `<` also starts a TS generic, which is harmless: the data layer only
-- answers inside an inline template. Letters are covered by blink's
-- show_on_keyword, so we deliberately omit space (it would pop the menu after
-- every space in a TS file).
function M:get_trigger_characters()
  return { "[", "(", ".", "<" }
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

-- A tag item inserts the whole element. The webapp writes paired tags almost
-- exclusively (28506 `</fl-x>` closings against 134 self-closing), so the
-- self-closing form is never worth offering. $1 sits in the start tag for
-- bindings, $0 in the body where the content goes.
local function tag_snippet(sel)
  return "<" .. sel .. "$1>$0</" .. sel .. ">"
end

-- Is the cross-file NgModule wiring in M:execute switched on? See the toggle at
-- the top of the file; anything unrecognised means the default.
local function wires_modules()
  local v = vim.g.angular_auto_wire
  return v ~= false and v ~= "standalone"
end

-- Will accepting be finished off by M:execute editing the owning @NgModule rather
-- than by the in-buffer edits? Both "…is NgModule-declared" refusals end up there,
-- provided it is the CONSUMER that is module-declared -- build_component_edits
-- reports the target first, so that half has to be read off the buffer.
-- The other half of the answer -- whether the owning module can already see the
-- target -- needs the repo-wide module index, far more than the 500ms budget
-- resolve gets during accept (blink drops the resolved item, and with it the
-- standalone edits, when that runs out). So the popup promises the attempt and the
-- notification on accept reports what actually came of it.
local function wires_via_module(reason)
  if not wires_modules() then return false end
  if reason == "consumer is NgModule-declared" then return true end
  if reason ~= "target is NgModule-declared" then return false end
  local c = require("gaf.angular").consumer_info(0)
  return c ~= nil and c.standalone == false
end

-- Why an accepted tag would NOT be wired up, per build_component_edits' `reason`.
-- `%s` is the target class; entries that don't name it just drop the argument.
local unwired = {
  ["target is NgModule-declared"] = "NgModule-declared — import not wired (add %s to the owning module)",
  ["consumer is NgModule-declared"] = "this component is NgModule-declared — import not wired (add %s to its @NgModule)",
  ["target is this component"] = "this component's own selector — nothing to import",
  ["cursor is not in a component template"] = "not inside a component template — import not wired",
  ["not an Angular component"] = "not an Angular component — import not wired",
}

-- Is this edit the `import { X } from '…'` statement rather than the decorator
-- entry? build_component_edits emits them in that order but either can be absent
-- (the buffer already has it), so a lone edit is told apart by its text: the
-- statement edit writes a new import line or rewrites an existing one, so its
-- newText always opens an import, while the decorator entry writes a bare class
-- name or an `imports: [` key -- neither of which does.
local function is_import_stmt(e)
  return e.newText:match("^%s*import%s") ~= nil
end

-- One line saying what accepting this tag does to the buffer, so an item that
-- silently wires nothing says so instead of inserting a tag that won't render.
local function wiring_line(info, edits)
  local cls = "`" .. ((info and info.class) or "?") .. "`"
  local reason = info and info.reason
  if reason then
    if wires_via_module(reason) then
      return "→ this component is NgModule-declared — on accept " .. cls ..
        " (or a module exporting it) goes into the owning `@NgModule`"
    end
    return "→ " .. string.format(unwired[reason] or (reason .. " — import not wired"), cls)
  end
  local stmt, entry = false, false
  for _, e in ipairs(edits) do
    if is_import_stmt(e) then stmt = true else entry = true end
  end
  local from = (info and info.spec) and (" from `" .. info.spec .. "`") or ""
  if stmt and entry then
    return "→ imports " .. cls .. from .. " and lists it in `imports: [ ]`"
  elseif stmt then
    return "→ imports " .. cls .. from .. " (already in `imports: [ ]`)"
  elseif entry then
    -- No statement edit with a known spec means the name is already imported;
    -- without one, build_import_edit had nowhere to import from and stayed out.
    if not (info and info.spec) then
      return "→ lists " .. cls .. " in `imports: [ ]` — no import path found, import it by hand"
    end
    return "→ lists " .. cls .. " in `imports: [ ]` (already imported)"
  end
  return "→ already imported and in `imports: [ ]` — nothing to add"
end

-- Docs popup for a tag item: the class the selector resolves to, how to get hold
-- of it, and what accepting will wire up. `info` is nil when the defining file no
-- longer parses.
local function tag_doc(sel, file, info, edits)
  local cls = (info and info.class) or "?"
  local parts = { "```typescript", "class " .. cls, "selector: '" .. sel .. "'", "```" }
  if info and info.spec then
    parts[#parts + 1] = ""
    parts[#parts + 1] = "→ `import { " .. cls .. " } from '" .. info.spec .. "'`"
  end
  local facts = {}
  if info and info.standalone ~= nil then
    facts[#facts + 1] = info.standalone and "standalone" or "module-declared"
  end
  if info and info.inputs then
    facts[#facts + 1] = info.inputs .. (info.inputs == 1 and " input" or " inputs")
  end
  facts[#facts + 1] = vim.fn.fnamemodify(file, ":t")
  parts[#parts + 1] = ""
  parts[#parts + 1] = table.concat(facts, " · ")
  parts[#parts + 1] = ""
  parts[#parts + 1] = wiring_line(info, edits)
  return table.concat(parts, "\n")
end

-- Modes 1-3 (enum member -> attribute value -> attribute name), tried in order.
-- Split out of get_completions so the tag mode can go in front of them without
-- adding a fourth level of nesting to this callback chain.
local function attr_completions(ctx, callback)
  local empty = { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
  local row = ctx.cursor[1] - 1
  local ng = require("gaf.angular")

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

function M:get_completions(ctx, callback)
  callback = vim.schedule_wrap(callback)

  -- 0. Component-TAG completion: cursor in `<fl-bu▏` inside an inline template.
  -- Tried first because at that point there is no attribute or value context for
  -- the later modes to read.
  require("gaf.angular").template_tag_completions(function(tags, meta)
    if not tags then return attr_completions(ctx, callback) end

    -- A bare `<` matches the whole ~4.8k-selector index: ~2ms to build the items
    -- and ~2ms for blink to score them, on every `<` in a template — including
    -- `<div`, which will never want this menu. Say "incomplete" instead and let
    -- blink come back the moment a letter narrows it.
    if (meta.prefix or "") == "" then
      return callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = {} })
    end

    local row = ctx.cursor[1] - 1
    local items = {}
    for i, t in ipairs(tags) do
      local text = tag_snippet(t.selector)
      items[i] = {
        label = t.selector,
        filterText = t.selector,
        sortText = t.selector,
        kind = kinds.Class,
        labelDetails = { description = t.dir },
        insertText = text,
        insertTextFormat = Snippet,
        textEdit = {
          newText = text,
          range = {
            -- Starts on the `<` the user already typed, so the snippet's own `<`
            -- replaces it rather than doubling up — blink's keyword begins after
            -- the bracket, the same left-extension the bindings above rely on.
            start = { line = row, character = meta.lt_col },
            ["end"] = { line = row, character = ctx.cursor[2] },
          },
        },
        -- Round-tripped to resolve() for the class/import docs.
        data = { file = t.file, selector = t.selector },
      }
    end
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
  end)
end

-- Enrich the focused item: a tag gets its component's class, its auto-import
-- edits and a line saying whether they will fire, an
-- input whose type is an exported enum gets its binding value seeded with `Enum.`
-- and, on accept, the enum imported into this buffer. Outputs are event handlers,
-- not enum values, so they're left untouched.
function M:resolve(item, callback)
  callback = vim.schedule_wrap(callback)
  local d = item.data
  if not d then return callback(item) end

  -- Tag items are the only ones carrying a file. On accept the component also has
  -- to become reachable from this consumer -- an `import` statement and an entry
  -- in its `@Component({ imports: [...] })` -- which build_component_edits works
  -- out (and refuses for the NgModule and self-reference cases). Only the focused
  -- item gets here, so the per-resolve parse it costs is paid ~once per keystroke,
  -- not 4.8k times per menu.
  if d.file and not d.type then
    local edits, info = require("gaf.angular").build_component_edits(0, d.file)
    return callback({
      -- The snippet textEdit is left untouched, so blink's deep-merge keeps it.
      documentation = { kind = "markdown", value = tag_doc(d.selector, d.file, info, edits) },
      additionalTextEdits = #edits > 0 and edits or nil,
    })
  end

  if not d.type or d.kind == "output" then return callback(item) end

  require("gaf.angular").resolve_enum(d.type, function(en)
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
    local ng = require("gaf.angular")
    local edits = {}
    local imp = ng.build_import_edit(0, name, en.spec, en.file)
    if imp then edits[#edits + 1] = imp end
    local fld = ng.build_enum_field_edit(0, name)
    if fld then edits[#edits + 1] = fld end
    if #edits > 0 then resolved.additionalTextEdits = edits end
    callback(resolved)
  end)
end

-- ── accepting a tag: the file the user isn't looking at ────────────────────

-- Where to say the edit landed. Relative to the source root the data layer indexes
-- under; that root is private to lua/gaf/angular/init.lua and this is display only, so
-- the patterns are mirrored rather than plumbed out -- a mismatch costs a longer
-- path and nothing else.
local function rel_path(file)
  local root = file:match("(.*/webapp/src)/") or file:match("(.*/webapp)/") or file:match("(.*/src)/")
  return root and file:sub(#root + 2) or vim.fn.fnamemodify(file, ":t")
end

-- Apply a `kind = "module"` plan to the file it names, and say so. Saving is
-- conditional: a buffer that was already modified holds the user's own unsaved
-- work and writing it would commit changes they never asked to commit, so it is
-- edited and handed back to them; a clean one is written because nothing else will
-- -- the file is off screen, and the change would be lost to the next :bd or
-- checkout. noautocmd keeps format-on-save off it: reformatting a file the user
-- never opened would bury a two-line wiring change in a whole-file diff.
local function apply_plan(plan)
  local bufnr = vim.fn.bufadd(plan.file)
  vim.fn.bufload(bufnr)
  local dirty = vim.bo[bufnr].modified
  vim.lsp.util.apply_text_edits(plan.edits, bufnr, "utf-8")
  -- Whether the write happened, not whether it was attempted: a failed one leaves
  -- the same modified buffer as the dirty case, and the message has to say so.
  local saved = false
  if not dirty then
    saved = pcall(vim.api.nvim_buf_call, bufnr, function() vim.cmd("noautocmd silent write") end)
  end
  vim.notify(
    plan.summary .. " — " .. rel_path(plan.file) .. (saved and " (saved)" or " (changed, left unsaved)"),
    vim.log.levels.INFO,
    { title = "Angular" }
  )
end

-- Accepting an item. blink's `default_implementation` applies the item itself --
-- textEdit, snippet and the additionalTextEdits resolve attached -- and everything
-- after it is the second file. `callback` completes blink's accept task, so it has
-- to fire exactly once down every path, thrown errors included.
function M:execute(ctx, item, callback, default_implementation)
  -- First, always: the tag and its snippet are what the user is waiting on, and
  -- the cross-file work below must never be in front of them.
  default_implementation()

  local d = item.data
  -- Tag items are the only ones carrying a file and no type; the binding items
  -- carry both, and have nothing to wire outside this buffer.
  if not d or not d.file or d.type then return callback() end
  if not wires_modules() then return callback() end

  local done = false
  local function finish()
    if done then return end
    done = true
    callback()
  end
  -- The plan reads a repo-wide index and parses another file; anything that throws
  -- in there -- synchronously here, or later from the index callback, where the
  -- error has no caller left to catch it -- would otherwise strand the accept task
  -- unresolved. The plan is asked for after the insert: it is derived from the
  -- enclosing component, which the inserted tag doesn't change.
  local ok = pcall(require("gaf.angular").build_ngmodule_plan, 0, d.file, function(plan)
    if plan and plan.kind == "module" then pcall(apply_plan, plan) end
    finish() -- a "none" plan says nothing: the docs popup already explained it
  end)
  if not ok then finish() end
end

return M
