-- Navigate Angular components by selector, with treesitter + ripgrep. No LSP.
--
-- GAF webapp uses inline `template:` only, so selector definitions and their
-- usages live in `.ts` files. The `angular` treesitter parser auto-injects into
-- the @Component template backtick string (see lua/plugins/treesitter.lua),
-- which lets us read tag/attribute names under the cursor precisely.
--
--   goto_parents()    -- cursor in a component -> components that use its selector (callers, "up")
--   goto_definition() -- cursor on a tag  -> that component's definition
--                        cursor on an attr -> the @Input/@Output (or directive) it refers to
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Angular" })
end

-- Escape rg-regex metacharacters that can appear in identifiers ($ in data$).
local function rx(s)
  return (s:gsub("([%$%.])", "\\%1"))
end

-- Search root: nearest .../webapp/src ancestor of the current file.
local function search_root(fname)
  return fname:match("(.*/webapp/src)/")
    or fname:match("(.*/webapp)/")
    or vim.fn.getcwd()
end

-- ── jump + picker plumbing ─────────────────────────────────────────────────

local function jump_to(file, lnum, col)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  pcall(vim.api.nvim_win_set_cursor, 0, { lnum, col or 0 })
  vim.cmd("normal! zz")
end

local function jump_item(item)
  jump_to(item.file, item.pos[1], item.pos[2])
end

-- Parse `rg --vimgrep` stdout into Snacks picker items, dropping `skip_file`.
local function vimgrep_items(stdout, skip_file)
  local items = {}
  for line in (stdout or ""):gmatch("[^\n]+") do
    local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
    if file and file ~= skip_file then
      table.insert(items, {
        text = vim.fn.fnamemodify(file, ":t") .. " " .. (text or ""),
        file = file,
        pos = { tonumber(lnum), tonumber(col) - 1 },
        line = text,
      })
    end
  end
  return items
end

-- Run rg --vimgrep with the given patterns over paths (root dir or files),
-- async, and hand the parsed items to cb on the main loop. ropts.no_type drops
-- the typescript filter (needed when searching explicit .scss files).
local function rg_run(patterns, paths, cb, ropts)
  ropts = ropts or {}
  local args = { "rg", "--vimgrep", "--no-heading", "--color=never" }
  if not ropts.no_type then
    vim.list_extend(args, { "-t", "ts", "-g", "!*.spec.ts" })
  end
  for _, p in ipairs(patterns) do
    vim.list_extend(args, { "-e", p })
  end
  vim.list_extend(args, paths)
  vim.system(args, { text = true }, function(res)
    vim.schedule(function() cb(vimgrep_items(res.stdout)) end)
  end)
end

-- Single hit -> jump straight; many -> fff-like picker.
-- opts.jump_first jumps to the first hit regardless of count (exact lookups);
-- opts.dedupe collapses to one item per file; opts.pick overrides picker fields.
local function show(title, items, opts)
  opts = opts or {}
  if opts.skip then
    items = vim.tbl_filter(function(it) return it.file ~= opts.skip end, items)
  end
  if opts.dedupe then
    local seen, uniq = {}, {}
    for _, it in ipairs(items) do
      if not seen[it.file] then
        seen[it.file] = true
        uniq[#uniq + 1] = it
      end
    end
    items = uniq
  end
  if #items == 0 then
    notify("No matches for " .. title)
    return
  end
  if opts.jump_first or #items == 1 then
    jump_item(items[1])
    return
  end
  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = title,
    items = items,
    format = "file",
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      if item then jump_item(item) end
    end,
  }, opts.pick or {}))
end

local function rg_search(title, patterns, root, opts)
  rg_run(patterns, { root }, function(items) show(title, items, opts) end)
end

-- ── treesitter helpers ─────────────────────────────────────────────────────

-- First tag_name in the subtree, depth-first (start_tag precedes nested content).
local function first_tag_name(node, buf)
  if node:type() == "tag_name" then
    return vim.treesitter.get_node_text(node, buf)
  end
  for child in node:iter_children() do
    local found = first_tag_name(child, buf)
    if found then return found end
  end
end

local TAG_NODES = { element = true, start_tag = true, self_closing_tag = true, end_tag = true }
local ATTR_NODES = {
  attribute = true, property_binding = true, event_binding = true,
  two_way_binding = true, structural_directive = true, bound_attribute = true,
}

-- Named node under the cursor in the injected (angular/html) tree.
local function injected_node(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "typescript")
  if not ok or not parser then return nil end
  parser:parse(true) -- include injections (template strings)
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]
  local lt = parser:language_for_range({ row, col, row, col })
  local tree = lt:tree_for_range({ row, col, row, col }, { ignore_injections = false })
  if not tree then return nil end
  return tree:root():named_descendant_for_range(row, col, row, col)
end

-- Classify what's under the cursor in a template:
--   { kind = "tag",  name = "app-foo" }
--   { kind = "attr", name = "someInput", tag = "app-foo" }  (tag may be nil)
local function target_under_cursor(buf)
  local node = injected_node(buf)
  while node do
    local t = node:type()
    if t == "tag_name" then
      return { kind = "tag", name = vim.treesitter.get_node_text(node, buf) }
    elseif ATTR_NODES[t] then
      -- e.g. `[foo]="bar"`, `(click)="x()"`, `*ngFor="..."`, `class="x"`, `flDir`.
      local raw = vim.treesitter.get_node_text(node, buf)
      local name = (raw:match("^[^=]*") or ""):gsub("[%s%[%]%(%)%*%#\"'@]", "")
      if name == "" then return nil end
      local tag
      local p = node
      while p do
        if TAG_NODES[p:type()] then
          tag = first_tag_name(p, buf)
          break
        end
        p = p:parent()
      end
      return { kind = "attr", name = name, tag = tag }
    elseif TAG_NODES[t] then
      return { kind = "tag", name = first_tag_name(node, buf) }
    end
    node = node:parent()
  end
end

-- ── rg pattern builders ────────────────────────────────────────────────────

-- Exact selector definition: the tag is a whole token, never `x-app-foo` or
-- `app-foo-bar`. Sole value, or a delimited member of a comma list.
local function selector_patterns(sel)
  sel = rx(sel)
  return {
    "selector:\\s*['\"]\\s*" .. sel .. "\\s*['\"]",
    "selector:\\s*['\"][^'\"]*[\\s,\\[]" .. sel .. "[\\s,\\]'\"]",
  }
end

-- Declarations of an @Input/@Output/signal/host-binding named `name`.
local function member_patterns(name)
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
local function directive_patterns(name)
  return { "selector:\\s*['\"][^'\"]*\\[" .. rx(name) .. "\\]" }
end

-- Locate a component by free-text name: matches a class declaration whose name
-- starts with `name` (so `Foo` finds `FooComponent`) and, when `name` looks like
-- a selector, its `selector:` definition too.
local function component_patterns(name)
  local pats = { "class\\s+" .. rx(name) }
  vim.list_extend(pats, selector_patterns(name))
  return pats
end

-- ── Direction 1: cursor in component -> parents (callers) ──────────────────

local function class_range_of(node)
  local n = node
  while n do
    if n:type() == "class_declaration" then
      local srow, _, erow = n:range()
      return srow, erow
    end
    n = n:parent()
  end
end

local function extract_selectors(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "typescript")
  if not ok or not parser then return {} end
  local tree = (parser:parse() or {})[1]
  if not tree then return {} end

  local ok_q, query = pcall(vim.treesitter.query.parse, "typescript", [[
    (decorator
      (call_expression
        function: (identifier) @fn (#eq? @fn "Component")
        arguments: (arguments
          (object
            (pair
              key: (property_identifier) @key (#eq? @key "selector")
              value: (string (string_fragment) @sel))))))
  ]])
  if not ok_q then return {} end

  local out = {}
  for id, node in query:iter_captures(tree:root(), buf, 0, -1) do
    if query.captures[id] == "sel" then
      local raw = vim.treesitter.get_node_text(node, buf)
      local srow, erow = class_range_of(node)
      for piece in tostring(raw):gmatch("[^,]+") do -- 'app-foo, [appFoo]'
        local sel = piece:gsub("[%[%]%*%s]", "")
        if sel ~= "" then
          table.insert(out, { selector = sel, srow = srow, erow = erow })
        end
      end
    end
  end
  return out
end

function M.goto_parents()
  if vim.bo.filetype ~= "typescript" then
    notify("Not a TypeScript component buffer", vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(buf)
  local selectors = extract_selectors(buf)
  if #selectors == 0 then
    notify("No @Component selector found in this file", vim.log.levels.WARN)
    return
  end

  -- Component enclosing the cursor if the file defines several; else all.
  local search
  if #selectors == 1 then
    search = { selectors[1].selector }
  else
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    for _, s in ipairs(selectors) do
      if s.srow and s.erow and row >= s.srow and row <= s.erow then
        search = { s.selector }
        break
      end
    end
    search = search or vim.tbl_map(function(s) return s.selector end, selectors)
  end

  -- Match the element opening tag only: `<app-foo` then a word boundary. Catches
  -- `<app-foo>`, `<app-foo/>` and multiline openers; skips closing tags and bare
  -- references, so each usage counts once. \b stops app-foo matching app-foobar.
  local patterns = {}
  for _, sel in ipairs(search) do
    table.insert(patterns, "<" .. rx(sel) .. "\\b")
  end
  rg_search("Parents of " .. table.concat(search, ", "), patterns, search_root(fname), {
    skip = fname,
    dedupe = true, -- one row per parent file
    pick = {
      format = "filename", -- show only the filename, not the path
      formatters = { file = { filename_only = true } },
    },
  })
end

-- ── Direction 2: cursor on a tag/attr -> its definition ────────────────────

-- Attribute lookup: find the element's component file, jump to the matching
-- @Input/@Output declaration; fall back to an attribute-selector directive.
local function goto_attr(name, tag, root)
  local function directive_fallback()
    rg_run(directive_patterns(name), { root }, function(items)
      if #items > 0 then
        jump_item(items[1])
      else
        notify("No definition found for attribute '" .. name .. "'", vim.log.levels.WARN)
      end
    end)
  end

  if tag and tag:find("%-") then
    rg_run(selector_patterns(tag), { root }, function(defs)
      local file = defs[1] and defs[1].file
      if not file then
        directive_fallback()
        return
      end
      rg_run(member_patterns(name), { file }, function(members)
        if #members > 0 then
          jump_item(members[1])
        else
          directive_fallback() -- attr is a directive applied to a component element
        end
      end)
    end)
  else
    directive_fallback() -- native element: attr can only be a directive
  end
end

-- ── CSS class -> component stylesheet ──────────────────────────────────────
-- A class used in a component's template is styled by that same component's
-- stylesheet (Angular view encapsulation), so we resolve the CURRENT file's
-- styleUrls -- not the child component's.

-- CSS identifier under the cursor (allows - and _).
local function class_token_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed at the cursor
  local b, e = col, col
  while b > 1 and line:sub(b - 1, b - 1):match("[%w_%-]") do b = b - 1 end
  while e <= #line and line:sub(e, e):match("[%w_%-]") do e = e + 1 end
  local tok = line:sub(b, e - 1)
  return tok ~= "" and tok or nil
end

-- Absolute, existing stylesheet paths from the component's styleUrls/styleUrl.
local function stylesheet_paths(buf)
  local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local rels = {}
  local arr = text:match("styleUrls%s*:%s*%[(.-)%]")
  if arr then
    for p in arr:gmatch("['\"]([^'\"]+)['\"]") do rels[#rels + 1] = p end
  end
  local single = text:match("styleUrl%s*:%s*['\"]([^'\"]+)['\"]")
  if single then rels[#rels + 1] = single end
  local paths = {}
  for _, rel in ipairs(rels) do
    local abs = vim.fs.normalize(dir .. "/" .. rel)
    if vim.uv.fs_stat(abs) then paths[#paths + 1] = abs end
  end
  return paths
end

-- Trailing BEM segment: TabsContainer--olarkEnabled -> --olarkEnabled (matches
-- scss `&--olarkEnabled` nested under the block).
local function bem_suffix(cls)
  local idx = 0
  for s in cls:gmatch("()%-%-") do idx = math.max(idx, s) end
  for s in cls:gmatch("()__") do idx = math.max(idx, s) end
  return idx > 0 and cls:sub(idx) or nil
end

-- Append `.cls { }` to the stylesheet, save, drop the cursor inside the braces.
local function create_class(file, cls)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  local last = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, last, last, false, { "", "." .. cls .. " {", "  ", "}" })
  vim.cmd("write")
  pcall(vim.api.nvim_win_set_cursor, 0, { last + 3, 2 })
  vim.cmd("normal! zz")
end

local function goto_css(cls, buf)
  local paths = stylesheet_paths(buf)
  if #paths == 0 then
    notify("No stylesheet (styleUrls) found for this component", vim.log.levels.WARN)
    return
  end
  local function offer_create()
    local target = paths[1]
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Class ." .. cls .. " not found. Create it in " .. vim.fn.fnamemodify(target, ":t") .. "?",
    }, function(choice)
      if choice == "Yes" then create_class(target, cls) end
    end)
  end
  -- 1) exact `.Class`  2) BEM `&--suffix`/`&__suffix`  3) offer to create.
  rg_run({ "\\." .. rx(cls) .. "\\b" }, paths, function(items)
    if #items > 0 then
      jump_item(items[1])
      return
    end
    local suf = bem_suffix(cls)
    if suf then
      rg_run({ "&" .. rx(suf) .. "\\b" }, paths, function(items2)
        if #items2 > 0 then jump_item(items2[1]) else offer_create() end
      end, { no_type = true })
    else
      offer_create()
    end
  end, { no_type = true })
end

function M.goto_definition()
  if vim.bo.filetype ~= "typescript" then
    notify("Not a TypeScript component buffer", vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local root = search_root(vim.api.nvim_buf_get_name(buf))

  local tgt = target_under_cursor(buf)
  if not tgt then
    notify("Cursor is not on a tag or attribute", vim.log.levels.WARN)
    return
  end

  if tgt.kind == "tag" then
    if not tgt.name or not tgt.name:find("%-") then
      notify("'" .. (tgt.name or "?") .. "' is a native element, not a component", vim.log.levels.WARN)
      return
    end
    -- Exact selector match -> jump straight, no picker.
    rg_search("Definition of " .. tgt.name, selector_patterns(tgt.name), root, { jump_first = true })
  else
    -- A class binding -> jump to the CSS; anything else -> @Input/@Output/directive.
    local name = tgt.name
    local cls
    if name:match("^class%.") then
      cls = name:sub(7) -- after "class."
    elseif name == "class" or name == "ngClass" then
      cls = class_token_under_cursor()
      if not cls or cls == "class" or cls == "ngClass" then
        notify("Place the cursor on a class name", vim.log.levels.WARN)
        return
      end
    end
    if cls then
      goto_css(cls, buf)
    else
      goto_attr(name, tgt.tag, root)
    end
  end
end

-- ── URL string -> routing module ───────────────────────────────────────────
-- Cursor on a route string like `/messages/thread/${thread.id}` -> walk the
-- Angular route tree from the app root, following loadChildren across files,
-- and land on the matching `path:` line in the deepest routing module.
--
-- Facts the walk relies on (verified in the GAF webapp):
--   * baseUrl is `src`, so a bare/aliased import specifier resolves to
--     `<src>/<specifier>`; `./` and `../` resolve against the importing file.
--   * loadChildren points at a `*.module.ts`, whose sibling
--     `*-routing.module.ts` holds the routes via `RouterModule.forChild(<id>)`.
--   * Every routing file declares `const <id>: Routes = [ ... ]`.
-- Limits (best-effort fallback to the deepest match / wildcard): custom
-- `matcher:` routes, `redirectTo` chains.

-- Sentinel marking a `${...}` interpolation -- treated as a param segment.
local PARAM = "\1"
local function seg_is_param(s)
  return s:find(PARAM, 1, true) ~= nil
end

local function split_path(p)
  local t = {}
  for s in p:gmatch("[^/]+") do
    t[#t + 1] = s
  end
  return t
end

-- Does `parts` (a route path split on /) match the front of `segs`?
-- Returns consumed-segment count and a quality score, or nil. Empty `''` and
-- `**` paths are handled by the caller, not here. A dynamic `${...}` segment is
-- only matched against a route `:param` (never a literal -- we won't guess that
-- a runtime value equals a specific literal path).
local function match_path(parts, segs)
  if #parts == 0 or parts[1] == "**" or #parts > #segs then
    return nil
  end
  local quality = 0
  for i = 1, #parts do
    local pp, sg = parts[i], segs[i]
    local pp_param, sg_param = pp:sub(1, 1) == ":", seg_is_param(sg)
    if pp_param and sg_param then
      quality = quality + 5 -- param aligns with dynamic value: ideal
    elseif pp_param then
      quality = quality + 3 -- route :param accepts a literal value
    elseif sg_param then
      return nil -- literal route vs dynamic segment: don't guess
    elseif pp == sg then
      quality = quality + 10 -- literal exact
    else
      return nil
    end
  end
  return #parts, quality
end

-- Resolve a module specifier to an existing .ts file. Relative specifiers
-- resolve against `from_dir`; everything else against the webapp `src` root.
local function resolve_module(spec, from_dir, src_root)
  local base
  if spec:match("^%.%.?/") then
    base = vim.fs.normalize(from_dir .. "/" .. spec)
  else
    base = src_root .. "/" .. spec
  end
  for _, c in ipairs({ base .. ".ts", base .. "/index.ts" }) do
    if vim.uv.fs_stat(c) then return c end
  end
end

-- Routing module for a loaded NgModule file: prefer the universal sibling
-- naming (foo.module.ts -> foo-routing.module.ts), else parse its imports.
local function routing_module_for(mod_file, src_root)
  local sibling = mod_file:gsub("%.module%.ts$", "-routing.module.ts")
  if sibling ~= mod_file and vim.uv.fs_stat(sibling) then
    return sibling
  end
  for _, line in ipairs(vim.fn.readfile(mod_file)) do
    local spec = line:match("from%s+['\"]([^'\"]+routing%.module)['\"]")
    if spec then
      local f = resolve_module(spec, vim.fs.dirname(mod_file), src_root)
      if f then return f end
    end
  end
end

-- Find the routes array node: the identifier/array passed to forChild/forRoot,
-- chasing an identifier to its `const <id> = [ ... ]` declaration.
local function find_call_arg(node, src)
  if node:type() == "call_expression" then
    local fn = node:field("function")[1]
    if fn and fn:type() == "member_expression" then
      local prop = fn:field("property")[1]
      local name = prop and vim.treesitter.get_node_text(prop, src)
      if name == "forChild" or name == "forRoot" then
        local args = node:field("arguments")[1]
        if args then return args:named_child(0) end
      end
    end
  end
  for c in node:iter_children() do
    local r = find_call_arg(c, src)
    if r then return r end
  end
end

local function find_var_array(node, src, name)
  if node:type() == "variable_declarator" then
    local n = node:field("name")[1]
    if n and vim.treesitter.get_node_text(n, src) == name then
      local v = node:field("value")[1]
      if v and v:type() == "as_expression" then v = v:named_child(0) end
      if v and v:type() == "array" then return v end
    end
  end
  for c in node:iter_children() do
    local r = find_var_array(c, src, name)
    if r then return r end
  end
end

local function find_routes_array(root, src)
  local arg = find_call_arg(root, src)
  if not arg then return nil end
  if arg:type() == "as_expression" then arg = arg:named_child(0) end
  if not arg then return nil end
  if arg:type() == "array" then return arg end
  if arg:type() == "identifier" then
    return find_var_array(root, src, vim.treesitter.get_node_text(arg, src))
  end
end

-- Read + parse a routing file off disk (not via a buffer). Returns
-- path, source string, routes-array node -- or nil.
local function load_routes_file(path)
  if not vim.uv.fs_stat(path) then return nil end
  local src = table.concat(vim.fn.readfile(path), "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "typescript")
  if not ok or not parser then return nil end
  local tree = (parser:parse() or {})[1]
  if not tree then return nil end
  local arr = find_routes_array(tree:root(), src)
  if not arr then return nil end
  return path, src, arr
end

-- Follow a loadChildren specifier to the target module's routing file.
local function open_loaded(spec, from_file, src_root)
  local mod = resolve_module(spec, vim.fs.dirname(from_file), src_root)
  if not mod then return nil end
  local routing = routing_module_for(mod, src_root)
  if not routing then return nil end
  return load_routes_file(routing)
end

local function unwrap(node)
  return node:type() == "as_expression" and node:named_child(0) or node
end

-- One route object -> { path, pos = {lnum,col}, children = <array|nil>,
-- load_spec = <string|nil> }. pos points at the `path:` value (else the object).
local function parse_route_object(obj, src)
  local r = {}
  for pair in obj:iter_children() do
    if pair:type() == "pair" then
      local key, val = pair:field("key")[1], pair:field("value")[1]
      local kname = key and vim.treesitter.get_node_text(key, src):gsub("['\"]", "")
      if kname == "path" and val and val:type() == "string" then
        r.path = vim.treesitter.get_node_text(val, src):gsub("^['\"]", ""):gsub("['\"]$", "")
        local row, col = val:range()
        r.pos = { row + 1, col }
      elseif kname == "children" and val then
        local v = unwrap(val)
        if v:type() == "array" then r.children = v end
      elseif kname == "loadChildren" and val then
        r.load_spec = vim.treesitter.get_node_text(val, src):match("import%(%s*['\"]([^'\"]+)['\"]")
      end
    end
  end
  if not r.pos then
    local row, col = obj:range()
    r.pos = { row + 1, col }
  end
  return r
end

local function parse_routes_in_array(arr, src)
  local routes = {}
  for obj in arr:iter_children() do
    if obj:type() == "object" then
      routes[#routes + 1] = parse_route_object(obj, src)
    end
  end
  return routes
end

-- Entry route of a routes list: the empty-path one, else the first.
local function entry_landing(routes, file)
  local empty, first
  for _, r in ipairs(routes) do
    first = first or r
    if r.path == "" then
      empty = r
      break
    end
  end
  local r = empty or first
  return r and { file = file, lnum = r.pos[1], col = r.pos[2] } or nil
end

-- Recursive descent: match `segs` against the routes in `arr` (from `file`),
-- crossing into lazy-loaded routing modules as needed. Returns the landing
-- { file, lnum, col, wildcard? } or nil.
local function resolve(arr, src, file, segs, src_root, depth)
  if depth > 40 then return nil end
  local routes = parse_routes_in_array(arr, src)

  if #segs == 0 then -- exhausted: land on this file's entry route
    return entry_landing(routes, file)
  end

  -- 1. best direct (non-empty, non-wildcard) match: more segments first, then
  -- match quality (literal > param). consumed dominates so a longer match always
  -- wins; quality (already weighted in match_path) only breaks ties.
  local best, best_score
  for _, r in ipairs(routes) do
    if r.path and r.path ~= "" then
      local consumed, quality = match_path(split_path(r.path), segs)
      if consumed then
        local score = consumed * 1000 + (quality or 0)
        if not best or score > best_score then
          best, best_score = { r = r, consumed = consumed }, score
        end
      end
    end
  end
  if best then
    local r = best.r
    local rest = {}
    for i = best.consumed + 1, #segs do rest[#rest + 1] = segs[i] end
    local here = { file = file, lnum = r.pos[1], col = r.pos[2] }
    if r.load_spec then
      local cf, cs, ca = open_loaded(r.load_spec, file, src_root)
      if not ca then return here end
      -- Match deeper; else land on the loaded module's entry, not this line.
      return resolve(ca, cs, cf, rest, src_root, depth + 1)
        or entry_landing(parse_routes_in_array(ca, cs), cf)
        or here
    elseif r.children and #rest > 0 then
      return resolve(r.children, src, file, rest, src_root, depth + 1) or here
    end
    return here
  end

  -- 2. transparent empty-path wrappers.
  for _, r in ipairs(routes) do
    if r.path == "" and r.children then
      local res = resolve(r.children, src, file, segs, src_root, depth + 1)
      if res then return res end
    end
  end

  -- 3. wildcard catch-all (last resort -- usually a 404/PHP redirect).
  for _, r in ipairs(routes) do
    if r.path == "**" then
      return { file = file, lnum = r.pos[1], col = r.pos[2], wildcard = true }
    end
  end
end

-- URL segments from the string/template under the cursor, with `${...}`
-- collapsed to a param sentinel and query/fragment stripped.
local function url_segments_under_cursor(buf)
  local node = vim.treesitter.get_node({ bufnr = buf })
  while node and node:type() ~= "string" and node:type() ~= "template_string" do
    node = node:parent()
  end
  if not node then return nil end
  local txt = vim.treesitter.get_node_text(node, buf)
  txt = txt:gsub("^[`'\"]", ""):gsub("[`'\"]$", "")
  txt = txt:gsub("[?#].*$", "")
  txt = txt:gsub("%$%b{}", PARAM)
  local segs = {}
  for s in txt:gmatch("[^/]+") do
    segs[#segs + 1] = s
  end
  return segs
end

-- Locate the webapp root app-routing module by walking up from `fname`.
-- Returns the app-routing path and the `src` dir (the import baseUrl), or nil.
-- Walks ancestors rather than slicing the path, so it works from any file in
-- the tree and across git worktrees (.../fl-gaf-worktree/Dxxxxx/webapp/...).
local function find_app_root(fname)
  for dir in vim.fs.parents(fname) do
    local cand = dir .. "/src/app/app-routing.module.ts"
    if vim.uv.fs_stat(cand) then
      return cand, dir .. "/src"
    end
  end
end

function M.goto_route()
  if vim.bo.filetype ~= "typescript" then
    notify("Not a TypeScript buffer", vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local segs = url_segments_under_cursor(buf)
  if not segs or #segs == 0 then
    notify("Place the cursor on a URL/route string", vim.log.levels.WARN)
    return
  end
  local app_routing, src_root = find_app_root(vim.api.nvim_buf_get_name(buf))
  if not app_routing then
    notify("Could not find webapp/src/app/app-routing.module.ts above this file", vim.log.levels.WARN)
    return
  end
  local file, src, arr = load_routes_file(app_routing)
  if not arr then
    notify("Could not parse " .. app_routing, vim.log.levels.WARN)
    return
  end
  local res = resolve(arr, src, file, segs, src_root, 0)
  local pretty = "/" .. table.concat(segs, "/"):gsub(PARAM, ":param")
  if not res then
    notify("No route matched " .. pretty, vim.log.levels.WARN)
    return
  end
  if res.wildcard then
    notify("No exact route for " .. pretty .. " -- landed on wildcard/catch-all", vim.log.levels.WARN)
  end
  jump_to(res.file, res.lnum, res.col)
end

-- ── Prompt for a component name -> its definition ──────────────────────────
-- Type a class name (`FooComponent`, prefix ok) or a selector (`app-foo`); jump
-- to the single hit, or pick when several match. Seeds the prompt with the
-- word under the cursor.
function M.goto_component_prompt()
  local buf = vim.api.nvim_get_current_buf()
  local root = search_root(vim.api.nvim_buf_get_name(buf))
  vim.ui.input({ prompt = "Component (class or selector): ", default = vim.fn.expand("<cword>") }, function(input)
    if not input then return end
    input = vim.trim(input)
    if input == "" then return end
    rg_search("Component " .. input, component_patterns(input), root, { dedupe = true })
  end)
end

return M
