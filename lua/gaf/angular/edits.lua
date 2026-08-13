-- The text edits that make an accepted completion compile: the `import`
-- statement, the `imports: [ ]` entry, the `Enum = Enum;` field a template needs
-- to reference an enum -- and, when the consumer is NgModule-declared, a PLAN
-- for the edit that belongs in a different file.
--
-- Nothing here applies, opens or prompts. Edits come back as LSP TextEdits so
-- the source applies them with the insertion in one undo block; the cross-file
-- plan comes back untouched, since editing a file the user isn't looking at is
-- their call.
local component = require("gaf.angular.component")
local module_index = require("gaf.angular.module_index")
local search = require("gaf.angular.search")
local ts = require("gaf.angular.ts")

local M = {}

-- ── this buffer ────────────────────────────────────────────────────────────

-- An LSP TextEdit importing `name` from `spec` into `bufnr`, or nil when it's
-- already imported, defined in this very file, or the spec is unknown. Merges
-- into an existing single-line import from the same module; else adds a new line
-- after the last import.
function M.build_import_edit(bufnr, name, spec, deffile)
  if not spec then return nil end
  if deffile and vim.api.nvim_buf_get_name(bufnr) == deffile then return nil end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- Already imported? (multiline-safe: scan every `import { … }` brace list.)
  for list in table.concat(lines, "\n"):gmatch("import%s*{(.-)}") do
    for tok in list:gmatch("[%w_]+") do
      if tok == name then return nil end
    end
  end
  -- End line of the LAST import: the line carrying `from '...'`, or the
  -- `import '...'` line for a side-effect import. A multi-line
  -- `import {\n … \n} from '…'` must advance to its closing line -- inserting
  -- after its `import {` opener produced broken TS.
  local last_import = -1
  local in_import = false
  for i, line in ipairs(lines) do
    if not in_import and line:match("^%s*import[%s{'\"*]") then in_import = true end
    if in_import then
      last_import = i - 1
      if line:match("from%s*['\"]") or line:match("^%s*import%s*['\"]") then in_import = false end
    end
    if line:match("import%s*{[^}]*}%s*from%s*['\"]" .. spec:gsub("[%-%.]", "%%%1") .. "['\"]") then
      return {
        range = { start = { line = i - 1, character = 0 }, ["end"] = { line = i - 1, character = #line } },
        newText = (line:gsub("{", "{ " .. name .. ",", 1)),
      }
    end
  end
  local at = last_import + 1
  return {
    range = { start = { line = at, character = 0 }, ["end"] = { line = at, character = 0 } },
    newText = "import { " .. name .. " } from '" .. spec .. "';\n",
  }
end

-- An LSP TextEdit adding `<name> = <name>;` as the class's first field -- the
-- GAF idiom for exposing an enum to a template, which can reference class
-- members but not imported symbols. nil when it is already exposed or no class
-- is found. The cursor sits in the decorator's template string, a sibling of the
-- class under the same `export_statement`, so walk up to that and back down.
function M.build_enum_field_edit(bufnr, name)
  local node = ts.node_at_cursor(bufnr)

  local cls
  while node do
    local t = node:type()
    if t == "class_declaration" then
      cls = node
      break
    elseif t == "export_statement" then
      cls = ts.child_by_type(node, "class_declaration")
      break
    end
    node = node:parent()
  end
  local body = cls and ts.child_by_type(cls, "class_body")
  if not body then return nil end

  local empty = true
  for m in body:iter_children() do
    local t = m:type()
    if t ~= "{" and t ~= "}" then empty = false end
    if t == "public_field_definition" then
      local nm, val = m:field("name")[1], m:field("value")[1]
      if nm and val
        and vim.treesitter.get_node_text(nm, bufnr) == name
        and vim.treesitter.get_node_text(val, bufnr) == name then
        return nil -- already exposed
      end
    end
  end

  local brace = ts.child_by_type(body, "{")
  if not brace then return nil end
  local _, _, br, bc = brace:range() -- end position of the `{`
  return {
    range = { start = { line = br, character = bc }, ["end"] = { line = br, character = bc } },
    newText = "\n  " .. name .. " = " .. name .. ";" .. (empty and "\n" or ""),
  }
end

-- ── the consuming @Component ───────────────────────────────────────────────

-- The @Component decorator whose inline template holds the cursor, as the nodes
-- an edit needs. Only when the innermost enclosing pair is `template:`, so a
-- cursor in `styles: [`…`]` -- also a template string inside the decorator --
-- doesn't count.
local function consumer_decorator(bufnr)
  local node = ts.node_at_cursor(bufnr)

  local tpl, dec
  while node do
    local t = node:type()
    if t == "pair" then
      tpl = tpl or node -- innermost pair: the decorator option we're inside
    elseif t == "decorator" then
      dec = node
      break
    elseif t == "class_declaration" or t == "export_statement" then
      return nil -- reached the class without crossing a decorator
    end
    node = node:parent()
  end
  if not dec or not tpl then return nil end
  local k = tpl:field("key")[1]
  if not k or (vim.treesitter.get_node_text(k, bufnr):gsub("['\"]", "")) ~= "template" then return nil end

  local dname, call = ts.decorator_call(dec, bufnr)
  if dname ~= "Component" or not call then return nil end
  local obj = ts.decorator_object(call)
  if not obj then return nil end

  local cls = ts.decorated_class(dec)
  local nn = cls and cls:field("name")[1]
  -- Same tri-state as component.info: absent means the decorator says nothing.
  local standalone
  local raw = ts.decorator_option(obj, "standalone", bufnr)
  if raw then standalone = raw == "true" end
  local ipair = ts.decorator_pair(obj, "imports", bufnr)
  local ival = ipair and ipair:field("value")[1]
  return {
    class = nn and vim.treesitter.get_node_text(nn, bufnr),
    standalone = standalone,
    obj = obj,
    anchor = tpl, -- a missing `imports:` key is created above `template:`
    imports_pair = ipair,
    imports = (ival and ival:type() == "array") and ival or nil,
  }
end

-- The component whose inline template holds the cursor in `bufnr`:
--   { class, standalone, decorator = <options-object range>, imports_range }
-- `standalone` is the raw tri-state: nil means no `standalone:` key, which
-- Angular 19 reads as true but an Angular 14 component meant as NgModule. Ask
-- `standalone ~= false`, not `== true`, before editing the decorator's imports.
function M.consumer_info(bufnr)
  local d = consumer_decorator(bufnr)
  if not d then return nil end
  return {
    class = d.class,
    standalone = d.standalone,
    decorator = ts.node_range(d.obj),
    imports_range = d.imports and ts.node_range(d.imports) or nil,
  }
end

-- ── growing an `imports:` array ────────────────────────────────────────────

-- Add `name` to an existing `imports: [...]` array node. Alphabetical placement
-- only when the array is *already* sorted -- slotting a name into the middle of
-- a hand-ordered list reads as diff noise. Formatting follows the array found
-- (line shape, trailing comma) so prettier has nothing to say.
local function imports_entry_edit(bufnr, arr, name)
  local entries, texts = {}, {}
  for c in arr:iter_children() do
    if c:named() and c:type() ~= "comment" then
      local txt = vim.treesitter.get_node_text(c, bufnr)
      if txt == name then return nil end -- already declared
      entries[#entries + 1] = c
      texts[#texts + 1] = txt
    end
  end

  if #entries == 0 then -- `imports: []`
    local open = ts.child_by_type(arr, "[")
    if not open then return nil end
    local _, _, er, ec = open:range()
    return ts.insert_at(er, ec, name)
  end

  local asr, _, aer = arr:range()
  local multiline = aer > asr

  local sorted = true
  for i = 2, #texts do
    if texts[i] < texts[i - 1] then
      sorted = false
      break
    end
  end
  local before
  if sorted then
    for i, t in ipairs(texts) do
      if t > name then
        before = i
        break
      end
    end
  end

  if before then
    local sr, sc = entries[before]:range()
    -- Insert at the entry's own column, not column 0: an entry that shares a line
    -- with another still gets a well-indented new line rather than a stray one.
    return ts.insert_at(sr, sc, multiline and (name .. ",\n" .. string.rep(" ", sc)) or (name .. ", "))
  end

  local last = entries[#entries]
  local _, lsc, ler, lec = last:range()
  if not multiline then
    return ts.insert_at(ler, lec, ", " .. name)
  end
  -- Step over the last entry's trailing comma when it has one (prettier writes
  -- one), and supply the separator ourselves when it doesn't -- appending after
  -- the comma is what keeps the insertion a pure addition to that line.
  local line = vim.api.nvim_buf_get_lines(bufnr, ler, ler + 1, false)[1] or ""
  local comma = line:sub(lec + 1, lec + 1) == ","
  return ts.insert_at(ler, comma and lec + 1 or lec,
    (comma and "" or ",") .. "\n" .. string.rep(" ", lsc) .. name .. (comma and "," or ""))
end

-- Create the missing `imports:` key, holding `name`, directly above the pair
-- `anchor`. For a @Component that's `template:` (1122 of the webapp's 1299
-- standalone components with an `imports` key put it there); for an @NgModule
-- it's the first key (1892 of 1975 modules lead with `imports`). Prettier never
-- reorders object keys, so nothing downstream moves it.
local function imports_key_edit(anchor, name)
  if not anchor then return nil end
  local sr, sc = anchor:range()
  return ts.insert_at(sr, sc, "imports: [" .. name .. "],\n" .. string.rep(" ", sc))
end

-- Add `name` to a decorator's `imports`: patch the array, or create the key.
-- Shared by the @Component and @NgModule consumers, which differ only in the
-- anchor. An `imports` that isn't an array literal (a spread, a shared const) is
-- not ours to rewrite, and a second key would be invalid TS.
local function decorator_imports_edit(bufnr, d, name)
  if d.imports_pair and not d.imports then return nil end
  if d.imports then return imports_entry_edit(bufnr, d.imports, name) end
  return imports_key_edit(d.anchor, name)
end

-- ── what an accepted tag needs ─────────────────────────────────────────────

-- Given the file the completed selector resolves to, the edits that make the tag
-- compile. Returns `edits, info` -- info is component.info(target_file) plus a
-- `reason` when there are no edits, so the source can explain the no-op instead
-- of silently inserting a tag that won't render. The decorator edit always sits
-- below the imports, so both travel in one `additionalTextEdits`.
function M.build_component_edits(bufnr, target_file)
  local info = component.info(target_file)
  if not info then return {}, { reason = "not an Angular component" } end
  info = vim.tbl_extend("force", {}, info) -- component.info hands back its cache

  if vim.api.nvim_buf_get_name(bufnr) == target_file then
    info.reason = "target is this component" -- a component using its own selector
    return {}, info
  end
  if info.standalone == false then
    info.reason = "target is NgModule-declared"
    return {}, info
  end
  local d = consumer_decorator(bufnr)
  if not d then
    info.reason = "cursor is not in a component template"
    return {}, info
  end
  if d.standalone == false then
    info.reason = "consumer is NgModule-declared" -- build_ngmodule_plan handles it
    return {}, info
  end

  -- Built one at a time: a table constructor holding a nil would truncate the
  -- list at it, dropping the edit after the one that wasn't needed.
  local edits = {}
  local import_edit = M.build_import_edit(bufnr, info.class, info.spec, target_file)
  if import_edit then edits[#edits + 1] = import_edit end
  local array_edit = decorator_imports_edit(bufnr, d, info.class)
  if array_edit then edits[#edits + 1] = array_edit end
  return edits, info
end

-- ── NgModule wiring: planning an edit in another file ──────────────────────
-- A `standalone: false` consumer has no `imports:` of its own to grow; what has
-- to change is the `imports:` of the NgModule DECLARING it, in another file.
-- module_index resolves which one; the output here is a plan, not an edit.

-- Import specifier for a module record, memoized on the record.
local function module_spec(m)
  if m.spec == nil then m.spec = component.import_spec(m.file, m.module_class) or false end
  return m.spec or nil
end

local function module_entry(m)
  return { module_class = m.module_class, file = m.file, spec = module_spec(m) }
end

-- Leading path components `a` and `b` share -- how close two files sit in the
-- directory tree.
local function shared_depth(a, b)
  local pa = vim.split(a, "/", { plain = true })
  local pb = vim.split(b, "/", { plain = true })
  local n = 0
  while pa[n + 1] and pa[n + 1] == pb[n + 1] do n = n + 1 end
  return n
end

-- Which exporting module to import when several export the target:
--   1. nearest the target in the directory tree -- a component's own feature
--      module, not an unrelated one that happens to re-export it;
--   2. shortest import specifier, preferring a barrel over a deep path;
--   3. file path, so the answer never depends on rg's ordering.
-- A module the consumer already imports is answered as "already reachable"
-- before anything gets here.
local function choose_exporter(exporters, target_file)
  local best
  for _, m in ipairs(exporters) do
    local e = module_entry(m)
    e.depth = shared_depth(e.file, target_file)
    e.speclen = e.spec and #e.spec or math.huge
    if not best
      or e.depth > best.depth
      or (e.depth == best.depth and e.speclen < best.speclen)
      or (e.depth == best.depth and e.speclen == best.speclen and e.file < best.file)
    then
      best = e
    end
  end
  return best
end

-- The `@NgModule` decorator on `class` in `bufnr`, shaped for
-- decorator_imports_edit. Anchor for a missing key is the object's first pair.
local function ngmodule_decorator(bufnr, class)
  local root = ts.buf_root(bufnr)
  if not root then return nil end

  local found
  ts.each_node(root, "decorator", function(dec)
    if found then return end
    local dname, call = ts.decorator_call(dec, bufnr)
    if dname ~= "NgModule" or not call then return end
    local cls = ts.decorated_class(dec)
    local nn = cls and cls:field("name")[1]
    if not nn or vim.treesitter.get_node_text(nn, bufnr) ~= class then return end
    local obj = ts.decorator_object(call)
    if not obj then return end
    local ipair = ts.decorator_pair(obj, "imports", bufnr)
    local ival = ipair and ipair:field("value")[1]
    local first
    for c in obj:iter_children() do
      if c:type() == "pair" then
        first = c
        break
      end
    end
    found = {
      obj = obj,
      anchor = first,
      imports_pair = ipair,
      imports = (ival and ival:type() == "array") and ival or nil,
    }
  end)
  return found
end

local function none(reason)
  return { kind = "none", reason = reason }
end

-- What it would take to make `target_file`'s selector resolve inside the
-- NgModule-declared component whose template holds the cursor. `cb(plan)`:
--   { kind = "none", reason }
--   { kind = "module", file, module_class, name, spec, edits, summary }
-- `edits` are LSP TextEdits against `file`, NOT `bufnr` -- built against a
-- bufadd+bufload buffer that is left loaded and unmodified. Applying and saving
-- is the caller's call.
function M.build_ngmodule_plan(bufnr, target_file, cb)
  local info = component.info(target_file)
  if not info then return cb(none("target is not an Angular component")) end
  if vim.api.nvim_buf_get_name(bufnr) == target_file then
    return cb(none("target is this component"))
  end
  -- Both of these read the cursor, so they must run before the index goes async.
  local consumer = M.consumer_info(bufnr)
  if not consumer then return cb(none("cursor is not in a component template")) end
  if consumer.standalone ~= false then
    return cb(none("consumer is standalone -- build_component_edits wires this up in place"))
  end
  if not consumer.class then return cb(none("could not read the consuming component's class")) end

  module_index.get(search.buf_root(bufnr), search.rg_run, function(idx)
    local owner = idx.declarer[consumer.class]
    if not owner then
      return cb(none("no NgModule declares " .. consumer.class))
    end
    local have = {}
    for _, id in ipairs(owner.imports) do have[id] = true end

    -- Reachable already? Three ways, all meaning an added import is redundant
    -- noise -- a consumer pulling an aggregate like UiModule already sees 147
    -- components.
    local target_owner = idx.declarer[info.class]
    if target_owner and target_owner.module_class == owner.module_class then
      return cb(none(owner.module_class .. " already declares " .. info.class))
    end
    local exporters = idx.exporters[info.class] or {}
    for _, m in ipairs(exporters) do
      if have[m.module_class] then
        return cb(none("already available via " .. m.module_class))
      end
    end

    -- A standalone component goes into the module's `imports` as itself (Angular
    -- allows that); an NgModule-declared one can only arrive via a module that
    -- exports it.
    local name, spec, deffile, alternatives
    if info.standalone ~= false then
      name, spec, deffile = info.class, info.spec, target_file
    else
      if #exporters == 0 then
        return cb(none("no NgModule exports " .. info.class .. ", so it cannot be imported"))
      end
      local pick = choose_exporter(exporters, target_file)
      name, spec, deffile = pick.module_class, pick.spec, pick.file
      alternatives = #exporters
    end
    if have[name] then
      return cb(none(owner.module_class .. " already imports " .. name))
    end

    local mbuf = vim.fn.bufadd(owner.file)
    vim.fn.bufload(mbuf)
    local d = ngmodule_decorator(mbuf, owner.module_class)
    if not d then
      return cb(none("could not find @NgModule " .. owner.module_class .. " in " .. owner.file))
    end
    if d.imports_pair and not d.imports then
      return cb(none(owner.module_class .. "'s imports is not an array literal we can edit"))
    end
    -- The buffer is the authority over the index here: it may hold an unsaved
    -- `imports` the index hasn't seen, and a nil edit then means "already there".
    local array_edit = decorator_imports_edit(mbuf, d, name)
    if not array_edit then
      return cb(none(owner.module_class .. " already imports " .. name))
    end
    local edits = {}
    local import_edit = M.build_import_edit(mbuf, name, spec, deffile)
    if import_edit then edits[#edits + 1] = import_edit end
    edits[#edits + 1] = array_edit

    local summary = "add " .. name .. " to " .. owner.module_class .. " imports"
    if alternatives and alternatives > 1 then
      summary = summary .. " (1 of " .. alternatives .. " modules exporting " .. info.class .. ")"
    end
    cb({
      kind = "module",
      file = owner.file,
      module_class = owner.module_class,
      name = name,
      spec = spec,
      edits = edits,
      summary = summary,
    })
  end)
end

return M
