-- Navigate Angular components by selector, with treesitter + ripgrep. No LSP.
-- Not GAF-specific: works in any Angular project (the GAF webapp is just one).
--
-- Tuned for INLINE-template Angular (`@Component({ template: `...` })`): selector
-- definitions and their usages live in `.ts` files, and the `angular` treesitter
-- parser auto-injects into the template backtick string (see
-- lua/plugins/treesitter.lua), which lets us read tag/attribute names under the
-- cursor precisely. Projects with external `.component.html` templates get the
-- .ts-side navigation (selectors, @Input/@Output, routes) but not the in-template
-- reads, which need the injected tree.
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

-- Search root: nearest Angular source ancestor of the current file. Prefer a
-- `webapp/src` (GAF monorepo layout), else any `webapp`, else a plain `src`
-- (standalone Angular repos), else the cwd. Tries the more specific patterns
-- first so a GAF file still narrows to `webapp/src`, not its outer `src`.
local function search_root(fname)
  return fname:match("(.*/webapp/src)/")
    or fname:match("(.*/webapp)/")
    or fname:match("(.*/src)/")
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
    vim.schedule(function()
      -- rg exits 1 for "no matches" (fine); anything else is a real failure
      -- (missing binary surfaces as ENOENT before this, bad pattern as 2).
      if res.code > 1 then
        vim.notify("rg failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
        return cb({})
      end
      cb(vimgrep_items(res.stdout))
    end)
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

-- Identifiers that live in a template *expression* (RHS of a binding, an event
-- handler, a structural `*ngIf`, or an `{{ interpolation }}`) rather than being
-- a tag or attribute name. These resolve to a TS definition, not the DOM.
local VALUE_CTX = { expression = true, interpolation = true, structural_expression = true }
-- Direct parent of an identifier that IS an attribute/binding NAME (not a value).
local NAME_PARENT = { binding_name = true, structural_directive = true }

-- If the cursor sits on an identifier inside a template expression, resolve the
-- symbol to look up: `{ name, member }`. For `ButtonSize.SMALL`, both the object
-- (`ButtonSize`) and the property (`SMALL`) yield name="ButtonSize", member="SMALL".
-- Returns nil when the cursor is on a tag/attribute name or plain markup.
local function symbol_under_cursor(buf)
  local node = injected_node(buf)
  if not node then return nil end
  local t = node:type()
  if t ~= "identifier" and t ~= "property_identifier" then return nil end
  local parent = node:parent()
  if parent and NAME_PARENT[parent:type()] then return nil end -- attr/binding name

  -- Must sit inside a value expression, not e.g. a plain quoted attribute.
  local in_value, anc = false, node
  while anc do
    if VALUE_CTX[anc:type()] then in_value = true break end
    if TAG_NODES[anc:type()] then break end
    anc = anc:parent()
  end
  if not in_value then return nil end

  local name = vim.treesitter.get_node_text(node, buf)
  local member
  if parent and parent:type() == "member_expression" then
    local obj = parent:field("object")[1]
    local prop = parent:field("property")[1]
    if prop and prop:id() == node:id() and obj then
      -- cursor on `.SMALL` -> the type is the object's rightmost identifier.
      local objtext = vim.treesitter.get_node_text(obj, buf)
      name = objtext:match("[%w_%$]+$") or objtext
      member = vim.treesitter.get_node_text(node, buf)
    elseif obj and obj:id() == node:id() and prop then
      -- cursor on `ButtonSize` -> keep it, remember the member to land on.
      member = vim.treesitter.get_node_text(prop, buf)
    end
  end
  return { name = name, member = member }
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

-- Definition of a type-like symbol referenced inside a template expression
-- (`[size]="ButtonSize.SMALL"` -> the `ButtonSize` enum/class/type/const).
local function symbol_def_patterns(name)
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

-- Declaration of a component-class member (`plainVar`, `onClick`) referenced in
-- a template expression -- anchored at line start so a template usage of the
-- same name (in the decorator above) is not mistaken for the declaration.
local function member_decl_patterns(name)
  name = rx(name)
  local mods = "(readonly\\s+|private\\s+|public\\s+|protected\\s+|static\\s+|override\\s+|abstract\\s+|get\\s+|set\\s+|async\\s+)*"
  -- Optional inline decorator before the member, e.g. `@Input({ required: true })
  -- foo$: Observable<...>` -- the name isn't at line start then. (`[^)]*` covers
  -- the common option-object/alias args; a decorator on its own line is matched by
  -- the plain form since the member line then starts with the name.)
  local decorator = "(@\\w+\\([^)]*\\)\\s*)?"
  return {
    "^\\s*" .. decorator .. mods .. name .. "\\s*[?!]?\\s*[:=(]",
    "^\\s*(public\\s+|private\\s+|protected\\s+|readonly\\s+)+" .. name .. "\\b",
  }
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

-- SCSS ampersand suffixes for a class produced by nested `&`-concatenation.
-- One candidate per delimiter run (`-`, `--`, `__`), so a class maps to any of
-- the `&`-nestings that could have built it:
--   `Data-name`      -> { "-name" }             (.Data { &-name {} })
--   `Tabs--olark`    -> { "--olark" }           (.Tabs { &--olark {} })
--   `Foo-bar-baz`    -> { "-bar-baz", "-baz" }  (one nest, or two)
-- Longest (closest-to-block) suffix first, so the most specific match wins.
local function bem_suffixes(cls)
  local out, seen = {}, {}
  for s in cls:gmatch("()[-_]+") do
    if s > 1 then -- a leading delimiter isn't a suffix of a parent block
      local suf = cls:sub(s)
      if not seen[suf] then
        seen[suf] = true
        out[#out + 1] = suf
      end
    end
  end
  table.sort(out, function(a, b) return #a > #b end)
  return out
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
    local sufs = bem_suffixes(cls)
    if #sufs > 0 then
      local pats = {}
      for _, s in ipairs(sufs) do pats[#pats + 1] = "&" .. rx(s) .. "\\b" end
      rg_run(pats, paths, function(items2)
        if #items2 > 0 then jump_item(items2[1]) else offer_create() end
      end, { no_type = true })
    else
      offer_create()
    end
  end, { no_type = true })
end

-- ── template-local declarations (@if `as`, @for vars, @let, *ngIf/*ngFor,
--    #refs, <ng-template let-x>) ─────────────────────────────────────────────
-- A name used in a template expression may be introduced by the template itself
-- rather than the component class -- an `@if (x$ | async; as foo)` alias, an
-- `@for (item of xs$)` loop variable, an `@let total = ...`, an `*ngIf="e as v"`
-- / `*ngFor="let i of ..."` binding, a `#ref`, or a `<ng-template let-ctx>` var.
-- `gd` on such a name should land on that binding site: the class-member search
-- never finds these, so it must run first. We collect every local the template
-- declares (with the node range it's visible in) and jump to the innermost
-- declaration whose scope encloses the cursor.

local function ancestor_of_type(node, t)
  local n = node
  while n do
    if n:type() == t then return n end
    n = n:parent()
  end
end

local function child_by_type(node, t)
  for c in node:iter_children() do
    if c:type() == t then return c end
  end
end

-- Record a declaration: identifier `id_node` is visible within `scope_node`.
-- opts.name/opts.col_off override the name/column (for `#ref`, `let-x` attrs).
local function push_local(out, buf, id_node, scope_node, opts)
  if not id_node or not scope_node then return end
  opts = opts or {}
  local dr, dc = id_node:range()
  local sr, sc, er, ec = scope_node:range()
  out[#out + 1] = {
    name = opts.name or vim.treesitter.get_node_text(id_node, buf),
    drow = dr + 1,
    dcol = dc + (opts.col_off or 0),
    srow = sr, scol = sc, erow = er, ecol = ec,
  }
end

-- Top-level `document` of an injected template tree (scope of template-wide refs).
local function template_root(node)
  local n = node
  while n:parent() do n = n:parent() end
  return n
end

-- Walk the injected angular tree, appending every declared local to `out`.
local function scan_locals(node, out, buf)
  local t = node:type()
  if t == "if_reference" then -- `@if (...; as x)` / `@else if (...; as x)`
    push_local(out, buf, child_by_type(node, "identifier"), node:parent())
  elseif t == "for_declaration" then -- `@for (item of xs)`
    local id = (node:field("name") or {})[1] or child_by_type(node, "identifier")
    push_local(out, buf, id, node:parent()) -- parent = for_statement (covers track expr + body)
  elseif t == "for_reference" then -- `@for (...; let i = $index)`
    local asgn = child_by_type(node, "assignment_expression")
    if asgn then push_local(out, buf, child_by_type(asgn, "identifier"), node:parent()) end
  elseif t == "let_statement" then -- `@let total = ...`
    local asgn = child_by_type(node, "assignment_expression")
    if asgn then push_local(out, buf, child_by_type(asgn, "identifier"), node:parent()) end
  elseif t == "structural_expression" then -- `*ngIf="e as v"`
    local armed, elem = false, ancestor_of_type(node, "element")
    for c in node:iter_children() do
      if c:type() == "special_keyword" and vim.treesitter.get_node_text(c, buf) == "as" then
        armed = true
      elseif armed and c:type() == "identifier" then
        push_local(out, buf, c, elem)
        break
      end
    end
  elseif t == "structural_declaration" then -- `*ngFor="let item of xs; let i = index"`
    local elem = ancestor_of_type(node, "element")
    for sa in node:iter_children() do
      if sa:type() == "structural_assignment" then
        local ids, let_kw = {}, false
        for c in sa:iter_children() do
          local ct = c:type()
          if ct == "special_keyword" and vim.treesitter.get_node_text(c, buf) == "let" then
            let_kw = true
          elseif ct == "identifier" then
            ids[#ids + 1] = c
          end
        end
        if let_kw and ids[1] then
          push_local(out, buf, ids[1], elem) -- `let i = index`
        elseif ids[2] then
          local sep = vim.treesitter.get_node_text(ids[2], buf)
          if sep == "of" or sep == "in" then
            push_local(out, buf, ids[1], elem) -- `let item of items`
          end
        end
      end
    end
  elseif t == "attribute_name" then
    local txt = vim.treesitter.get_node_text(node, buf)
    if txt:sub(1, 1) == "#" then -- `#ref` -- visible across the whole template
      push_local(out, buf, node, template_root(node), { name = txt:sub(2), col_off = 1 })
    elseif txt:sub(1, 4) == "let-" then -- `<ng-template let-ctx>`
      push_local(out, buf, node, ancestor_of_type(node, "element"), { name = txt:sub(5), col_off = 4 })
    end
  end
  for c in node:iter_children() do
    scan_locals(c, out, buf)
  end
end

local function scope_encloses(d, row, col)
  if row < d.srow or row > d.erow then return false end
  if row == d.srow and col < d.scol then return false end
  if row == d.erow and col >= d.ecol then return false end
  return true
end

-- If `name` binds to a template-local declaration in scope at the cursor, jump to
-- its binding site and return true; else return false so the class-member search
-- runs. The innermost enclosing declaration (latest-starting scope) wins.
local function goto_template_local(buf, name)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "typescript")
  if not ok or not parser then return false end
  parser:parse(true)
  local out = {}
  parser:for_each_tree(function(tree, ltree)
    if ltree:lang() == "angular" then scan_locals(tree:root(), out, buf) end
  end)

  local pos = vim.api.nvim_win_get_cursor(0)
  local crow, ccol = pos[1] - 1, pos[2]
  local best
  for _, d in ipairs(out) do
    if d.name == name and scope_encloses(d, crow, ccol) then
      if not best or d.srow > best.srow or (d.srow == best.srow and d.scol > best.scol) then
        best = d
      end
    end
  end
  if not best then return false end
  jump_to(vim.api.nvim_buf_get_name(buf), best.drow, best.dcol)
  return true
end

-- Jump to a value symbol's definition. PascalCase/CONST names -> a type, enum,
-- class or const anywhere under the search root (landing on `member` inside it
-- when the cursor was on `Enum.MEMBER`); lowerCamel names -> a class member
-- declared in the component file itself.
local function goto_symbol(name, member, buf, root)
  local function land(item)
    if not member then jump_item(item); return end
    rg_run({ "\\b" .. rx(member) .. "\\b" }, { item.file }, function(m)
      jump_item(m[1] or item)
    end)
  end

  if name:match("^%u") then
    rg_run(symbol_def_patterns(name), { root }, function(items)
      if #items == 0 then
        notify("No type/enum/class definition found for '" .. name .. "'", vim.log.levels.WARN)
      elseif #items == 1 or member then
        land(items[1])
      else
        show("Definition of " .. name, items, { dedupe = true })
      end
    end)
  else
    local fname = vim.api.nvim_buf_get_name(buf)
    rg_run(member_decl_patterns(name), { fname }, function(items)
      if #items > 0 then
        jump_item(items[1])
      else
        notify("No definition found for '" .. name .. "'", vim.log.levels.WARN)
      end
    end, { no_type = true })
  end
end

-- Returns true when the cursor was on an Angular template target (tag, attribute,
-- CSS class, or a symbol in a binding expression) and this function claimed the
-- jump -- even if the target could not be resolved. Returns false only when the
-- cursor is on plain TypeScript, so the caller can fall back to LSP `gd`.
function M.goto_definition()
  if vim.bo.filetype ~= "typescript" then return false end
  local buf = vim.api.nvim_get_current_buf()
  local root = search_root(vim.api.nvim_buf_get_name(buf))

  -- A symbol in a binding value/interpolation (`ButtonSize.SMALL`, `plainVar`)
  -- resolves to its TS definition, before tag/attribute classification. A name
  -- the template itself binds (`@if ... as x`, `@for` var, `@let`, `#ref`) wins
  -- over the class-member search -- that's the name's lexical declaration.
  local sym = symbol_under_cursor(buf)
  if sym then
    if not goto_template_local(buf, sym.name) then
      goto_symbol(sym.name, sym.member, buf, root)
    end
    return true
  end

  local tgt = target_under_cursor(buf)
  if not tgt then return false end -- plain TS: let the caller use LSP definition

  if tgt.kind == "tag" then
    if not tgt.name or not tgt.name:find("%-") then
      notify("'" .. (tgt.name or "?") .. "' is a native element, not a component", vim.log.levels.WARN)
      return true
    end
    -- Selector definition: one file -> jump straight; multiple files defining the
    -- same selector (e.g. projects + contests both define `app-collaborator-info`)
    -- -> picker, so a duplicated name is still reachable.
    rg_search("Definition of " .. tgt.name, selector_patterns(tgt.name), root, { dedupe = true })
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
        return true
      end
    end
    if cls then
      goto_css(cls, buf)
    else
      goto_attr(name, tgt.tag, root)
    end
  end
  return true
end

-- ── URL string -> routing module ───────────────────────────────────────────
-- Cursor on a route string like `/messages/thread/${thread.id}` -> walk the
-- Angular route tree from the app root, following loadChildren across files,
-- and land on the matching `path:` line in the deepest routing module.
--
-- Facts the walk relies on (standard Angular conventions; verified in the GAF webapp):
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

-- ── inline-template @Input/@Output completion data ─────────────────────────
-- Feeds a blink.cmp source (lua/angular/inputs_source.lua): when the cursor is
-- inside a component start tag (`<app-foo …>`) in an inline template, offer that
-- component's @Input/@Output/signal members as completion items, with types.
-- The heavy lookup (rg for the selector's file) is cached per selector, and the
-- parsed member list is cached per file+mtime, so only the first hit on a fresh
-- tag pays the rg cost -- everything after is a table read.

-- The component tag whose *open* start tag encloses the cursor (`<app-foo …▏`),
-- or nil. A backward text scan, deliberately NOT treesitter: while the attribute
-- is still being typed the tag is unclosed, and treesitter's error recovery
-- misattributes the cursor to the nearest well-formed *enclosing* element (so a
-- cursor in `<app-foo [` resolves to the surrounding `<div>`). Instead we take
-- the last `<tag` before the cursor with no intervening `>` -- precisely the
-- "inside an open start tag" state that completion fires in. Scans a 30-line
-- window so multiline start tags resolve. The caller gates on a `-` in the name
-- (component selectors always have one), discarding the false hits this can
-- produce -- a `<` in a binding expression, or a TS generic like `Array<`.
local function enclosing_tag_name(buf)
  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buf, math.max(0, pos[1] - 30), pos[1], false)
  if #lines == 0 then return nil end
  lines[#lines] = lines[#lines]:sub(1, pos[2]) -- up to the cursor only
  local text = table.concat(lines, "\n")
  local lt = text:find("<[^<>]*$") -- last `<` with no `<`/`>` after it
  if not lt then return nil end
  return text:sub(lt):match("^<([%w%-]+)")
end

-- True when the cursor sits inside a quoted attribute value of the current open
-- start tag (typing a binding *value*, not an attribute *name*). Tracks quote
-- state across the tag segment from the last `<` to the cursor.
local function in_attr_value(buf)
  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buf, math.max(0, pos[1] - 30), pos[1], false)
  if #lines == 0 then return false end
  lines[#lines] = lines[#lines]:sub(1, pos[2])
  local text = table.concat(lines, "\n")
  local lt = text:find("<[^<>]*$")
  if not lt then return false end
  local q
  for ch in text:sub(lt):gmatch(".") do
    if q then
      if ch == q then q = nil end
    elseif ch == '"' or ch == "'" then
      q = ch
    end
  end
  return q ~= nil
end

-- True when the cursor is inside a `template_string` (a `@Component` inline
-- template). Uses the plain TS tree -- present regardless of the angular
-- injection -- so it's reliable even before the injected parser has run.
local function in_template(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "typescript")
  if not ok or not parser then return false end
  local tree = (parser:parse() or {})[1]
  if not tree then return false end
  local pos = vim.api.nvim_win_get_cursor(0)
  local node = tree:root():named_descendant_for_range(pos[1] - 1, pos[2], pos[1] - 1, pos[2])
  while node do
    if node:type() == "template_string" then return true end
    node = node:parent()
  end
  return false
end

local function strip_ann(s)
  return (s:gsub("^%s*:%s*", ""))
end

-- Strip comment markers from a doc comment's raw text -> clean markdown-ish body.
-- Handles `/** … */` / `/* … */` (drops the delimiters and per-line leading `*`)
-- and `//` line comments.
local function clean_comment(text)
  text = text:gsub("^/%*%*?", ""):gsub("%*/%s*$", "")
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("^%s*%*+%s?", "") -- block-comment continuation `*`
    line = line:gsub("^%s*//+%s?", "") -- line comment
    lines[#lines + 1] = line
  end
  return vim.trim(table.concat(lines, "\n"))
end

-- The doc comment attached to `member`: the contiguous `comment` siblings
-- collected in `comments`, but only when the block sits directly above the
-- member (a gap means it documents something else / is a stray comment).
local function leading_doc(comments, member, src)
  if #comments == 0 then return nil end
  local msrow = member:range()
  local _, _, lerow = comments[#comments]:range()
  if msrow - lerow > 1 then return nil end -- not adjacent
  local parts = {}
  for _, c in ipairs(comments) do
    parts[#parts + 1] = clean_comment(vim.treesitter.get_node_text(c, src))
  end
  local doc = vim.trim(table.concat(parts, "\n"))
  return doc ~= "" and doc or nil
end

-- First balanced `<...>` generic argument in a call/new-expression's text
-- (`EventEmitter<Map<a,b>>` -> `Map<a,b>`, `input<ButtonSize>()` -> `ButtonSize`).
local function angle_generic(text)
  local i = text:find("<")
  if not i then return nil end
  local depth = 0
  for k = i, #text do
    local ch = text:sub(k, k)
    if ch == "<" then
      depth = depth + 1
    elseif ch == ">" then
      depth = depth - 1
      if depth == 0 then
        local inner = vim.trim(text:sub(i + 1, k - 1))
        return inner ~= "" and inner or nil
      end
    end
  end
end

-- Decorator's called name + its call node: `@Input('x')` -> "Input", <call>.
local function decorator_call(dec, src)
  for c in dec:iter_children() do
    local t = c:type()
    if t == "call_expression" then
      local fn = c:field("function")[1]
      return fn and vim.treesitter.get_node_text(fn, src), c
    elseif t == "identifier" then -- `@Input` with no parens
      return vim.treesitter.get_node_text(c, src), nil
    end
  end
end

-- First argument of a call if it's a string literal (the @Input/@Output alias).
local function first_string_arg(call, src)
  if not call then return nil end
  local args = call:field("arguments")[1]
  local a = args and args:named_child(0)
  if a and a:type() == "string" then
    return (vim.treesitter.get_node_text(a, src):gsub("['\"]", ""))
  end
end

-- Type of an @Input setter's parameter: `set x(v: T)` -> "T".
local function setter_param_type(method, src)
  local params = method:field("parameters")[1]
  local p = params and params:named_child(0)
  if not p then return nil end
  for c in p:iter_children() do
    if c:type() == "type_annotation" then
      return strip_ann(vim.treesitter.get_node_text(c, src))
    end
  end
end

-- Classify one class member -> { name, prop, kind = input|output|model, type,
-- doc } or nil. `name` is the template binding name (alias if any), `prop` the
-- field, `doc` the cleaned leading comment (or nil). `pending` holds decorator
-- nodes that preceded the member as siblings (how the TS parser attaches a
-- decorator to a setter method, vs a field where it's a child).
local function member_input(member, pending, doc, src)
  local mt = member:type()
  if mt ~= "public_field_definition" and mt ~= "method_definition" then return nil end
  local nn = member:field("name")[1]
  if not nn then return nil end
  local prop = vim.treesitter.get_node_text(nn, src)

  local decs = {}
  for _, d in ipairs(pending) do decs[#decs + 1] = d end
  for c in member:iter_children() do
    if c:type() == "decorator" then decs[#decs + 1] = c end
  end

  -- 1. classic @Input()/@Output() decorator.
  for _, d in ipairs(decs) do
    local dn, call = decorator_call(d, src)
    if dn == "Input" or dn == "Output" then
      local kind = dn == "Input" and "input" or "output"
      local ty
      if kind == "input" then
        if mt == "method_definition" then
          ty = setter_param_type(member, src)
        else
          local tn = member:field("type")[1]
          ty = tn and strip_ann(vim.treesitter.get_node_text(tn, src))
        end
      else -- output: the EventEmitter<T> payload from the initialiser
        local v = member:field("value")[1]
        ty = v and angle_generic(vim.treesitter.get_node_text(v, src))
      end
      return { name = first_string_arg(call, src) or prop, prop = prop, kind = kind, type = ty, doc = doc }
    end
  end

  -- 2. signal API: `x = input<T>() / input.required<T>() / model<T>() / output<T>()`.
  if mt == "public_field_definition" then
    local v = member:field("value")[1]
    if v and v:type() == "call_expression" then
      local vt = vim.treesitter.get_node_text(v, src)
      local base = (vt:match("^([%w_%.]+)") or ""):match("^([%w_]+)")
      local kind = base == "input" and "input"
        or base == "model" and "model"
        or base == "output" and "output"
        or nil
      if kind then
        local alias = vt:match("alias%s*:%s*['\"]([^'\"]+)")
        return { name = alias or prop, prop = prop, kind = kind, type = angle_generic(vt), doc = doc }
      end
    end
  end
end

local function each_node(node, t, cb)
  if node:type() == t then cb(node) end
  for c in node:iter_children() do each_node(c, t, cb) end
end

-- Every @Input/@Output/signal member declared in `file`, deduped by binding
-- name. Reads + parses off disk (no buffer); scans all classes in the file
-- (component files hold one class in practice, so cross-class mixing is moot).
local function parse_inputs(file)
  local src = table.concat(vim.fn.readfile(file), "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "typescript")
  if not ok or not parser then return {} end
  local tree = (parser:parse() or {})[1]
  if not tree then return {} end

  local out, seen = {}, {}
  each_node(tree:root(), "class_body", function(body)
    local pending, comments = {}, {}
    for member in body:iter_children() do
      local mt = member:type()
      if mt == "decorator" then
        pending[#pending + 1] = member
      elseif mt == "comment" then
        comments[#comments + 1] = member
      else
        local r = member_input(member, pending, leading_doc(comments, member, src), src)
        if r and not seen[r.name] then
          seen[r.name] = true
          out[#out + 1] = r
        end
        if mt == "public_field_definition" or mt == "method_definition" then
          pending, comments = {}, {}
        end
      end
    end
  end)
  return out
end

local sel_file_cache = {} -- selector -> component file path, or false (no def)
local input_cache = {}    -- file -> { mtime = <sec>, list = { ... } }

local function inputs_for_file(file)
  local st = vim.uv.fs_stat(file)
  if not st then return {} end
  local c = input_cache[file]
  if c and c.mtime == st.mtime.sec then return c.list end
  local list = parse_inputs(file)
  input_cache[file] = { mtime = st.mtime.sec, list = list }
  return list
end

-- ── enum resolution + auto-import (drives value-seeding in the blink source) ─
-- When an input's type is an exported enum (`[size]="ButtonSize.…"`), the source
-- seeds the binding value with the enum and, on accept, adds the missing import.
-- Resolving the enum's file/members costs one rg + one parse, cached per type.

local type_cache = {} -- type name -> resolved def (enum|union) or false (neither)

-- Does the barrel `index_file` re-export `name`? Matches a named re-export
-- (`export { … name … }`), a direct `export enum name`, or any `export *`
-- (wildcard -- assume it may carry the symbol).
local function reexports(index_file, name)
  local txt = table.concat(vim.fn.readfile(index_file), "\n")
  for list in txt:gmatch("export%s*{(.-)}") do
    for tok in list:gmatch("[%w_]+") do
      if tok == name then return true end
    end
  end
  if txt:match("export%s*%*%s*from") then return true end
  if txt:match("export[^\n]-enum%s+" .. name .. "%f[%W]") then return true end
  return false
end

-- Public import specifier for the file defining `name`, assuming baseUrl = `src`
-- (verified in the GAF webapp). Prefers the nearest ancestor barrel (an
-- `index.ts` re-exporting `name`) so we import `@freelancer/ui/button`, not the
-- deep `@freelancer/ui/button/button-size`. Falls back to the file's own
-- src-relative path when no barrel re-exports it.
local function import_spec(file, name)
  local src = file:match("(.*/webapp/src)/") or file:match("(.*/src)/")
  if not src then return nil end
  if file:match("/index%.ts$") then -- enum declared straight in a barrel
    return vim.fs.dirname(file):sub(#src + 2)
  end
  local dir = vim.fs.dirname(file)
  while dir and #dir > #src do
    local idx = dir .. "/index.ts"
    if vim.uv.fs_stat(idx) and reexports(idx, name) then
      return dir:sub(#src + 2)
    end
    dir = vim.fs.dirname(dir)
  end
  return (file:sub(#src + 2):gsub("%.ts$", ""))
end

-- Member names of `enum <name>` declared in `file`.
local function enum_members(file, name)
  local src = table.concat(vim.fn.readfile(file), "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "typescript")
  if not ok then return {} end
  local tree = (parser:parse() or {})[1]
  if not tree then return {} end
  local out = {}
  each_node(tree:root(), "enum_declaration", function(ed)
    local id = child_by_type(ed, "identifier")
    if not id or vim.treesitter.get_node_text(id, src) ~= name then return end
    local body = child_by_type(ed, "enum_body")
    if not body then return end
    for c in body:iter_children() do
      local pid = c:type() == "property_identifier" and c
        or (c:type() == "enum_assignment" and child_by_type(c, "property_identifier"))
      if pid then out[#out + 1] = vim.treesitter.get_node_text(pid, src) end
    end
  end)
  return out
end

-- RHS of `export type <name> = …` in `file`, or nil.
local function type_alias_value(file, name)
  local src = table.concat(vim.fn.readfile(file), "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "typescript")
  if not ok then return nil end
  local tree = (parser:parse() or {})[1]
  if not tree then return nil end
  local out
  each_node(tree:root(), "type_alias_declaration", function(n)
    local nm, val = n:field("name")[1], n:field("value")[1]
    if nm and val and vim.treesitter.get_node_text(nm, src) == name then
      out = vim.treesitter.get_node_text(val, src)
    end
  end)
  return out
end

-- Reduce a type annotation to a lone named type, dropping ` | null`,
-- ` | undefined`, `readonly`, and a trailing `[]` -- so `ButtonSize | null` and
-- `readonly ButtonSize[]` both yield `ButtonSize`. nil when what remains isn't a
-- single PascalCase identifier.
local function enum_name_of(t)
  local core = t:gsub("%s*|%s*null", ""):gsub("%s*|%s*undefined", ""):gsub("readonly%s+", ""):gsub("%[%]", "")
  core = vim.trim(core)
  return core:match("^%u[%w_]*$") and core or nil
end

-- Classify an input's declared type for value completion:
--   { kind = "enum",  name = "ButtonSize" }              (bare/nullable enum)
--   { kind = "union", values = { "'a'", "'b'" } }        (string/number literals)
-- or nil. A union with any non-literal, non-null member is not offered.
local function classify_type(t)
  local name = enum_name_of(t)
  if name then return { kind = "enum", name = name } end
  local vals, pure, has = {}, true, false
  for part in t:gmatch("[^|]+") do
    part = vim.trim(part)
    if part == "" or part == "null" or part == "undefined" then -- ignore
    elseif part:match("^'[^']*'$") or part:match('^"[^"]*"$') or part:match("^%-?%d+%.?%d*$") then
      vals[#vals + 1] = part
      has = true
    else
      pure = false
    end
  end
  if has and pure then return { kind = "union", values = vals } end
end

-- Resolve a named type (bare or nullable) to its exported definition, for value
-- completion. `cb` gets one of, or nil (cached per normalized name, misses too):
--   { kind = "enum",  name, file, spec, members }   -- `export enum X`
--   { kind = "union", name, file, spec, values }    -- `export type X = 'a'|'b'`
-- A string-valued enum in Angular is often modelled as a string-literal type
-- alias, not an `enum` -- both resolve here so both drive completion.
function M.resolve_type(type_name, cb)
  local core = enum_name_of(type_name)
  if not core then return cb(nil) end
  local cached = type_cache[core]
  if cached ~= nil then return cb(cached or nil) end
  local root = search_root(vim.api.nvim_buf_get_name(0))
  local pats = {
    "export\\s+(declare\\s+)?(const\\s+)?enum\\s+" .. rx(core) .. "\\b",
    "export\\s+type\\s+" .. rx(core) .. "\\b",
  }
  rg_run(pats, { root }, function(items)
    local hit = items[1]
    local res
    if hit and hit.line and hit.line:match("enum%s+" .. core .. "%f[%W]") then
      res = { kind = "enum", name = core, file = hit.file,
        spec = import_spec(hit.file, core), members = enum_members(hit.file, core) }
    elseif hit then
      local cls = classify_type(type_alias_value(hit.file, core) or "")
      if cls and cls.kind == "union" then
        res = { kind = "union", name = core, file = hit.file,
          spec = import_spec(hit.file, core), values = cls.values }
      end
    end
    type_cache[core] = res or false
    cb(res)
  end)
end

-- Enum-only view of resolve_type (for `Enum.` member completion + attr seeding).
function M.resolve_enum(type_name, cb)
  M.resolve_type(type_name, function(t) cb(t and t.kind == "enum" and t or nil) end)
end

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
  -- Track the end line of the LAST import statement. A statement ends on the
  -- line carrying its module specifier (`from '...'`) or, for a side-effect
  -- import, the `import '...'` line itself -- so a multi-line
  -- `import {\n … \n} from '…'` advances last_import to its closing line, not
  -- its `import {` opener (inserting after the opener produced broken TS).
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

-- An LSP TextEdit adding `<name> = <name>;` as the first field of the component
-- class whose inline template holds the cursor -- the GAF idiom for exposing an
-- enum to a template (a template can only reference class members, not imported
-- symbols). nil when the class already exposes it, or no class is found. The
-- cursor sits in the `@Component` decorator's template string, a sibling of the
-- class under the same `export_statement`, so we walk up to that and back down.
function M.build_enum_field_edit(bufnr, name)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "typescript")
  if not ok or not parser then return nil end
  local tree = (parser:parse() or {})[1]
  if not tree then return nil end
  local pos = vim.api.nvim_win_get_cursor(0)
  local node = tree:root():named_descendant_for_range(pos[1] - 1, pos[2], pos[1] - 1, pos[2])

  local cls
  while node do
    local t = node:type()
    if t == "class_declaration" then
      cls = node
      break
    elseif t == "export_statement" then
      cls = child_by_type(node, "class_declaration")
      break
    end
    node = node:parent()
  end
  local body = cls and child_by_type(cls, "class_body")
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

  local brace = child_by_type(body, "{")
  if not brace then return nil end
  local _, _, br, bc = brace:range() -- end position of the `{`
  return {
    range = { start = { line = br, character = bc }, ["end"] = { line = br, character = bc } },
    newText = "\n  " .. name .. " = " .. name .. ";" .. (empty and "\n" or ""),
  }
end

-- Resolve the component tag under the cursor to its member list and call
-- `cb(inputs, { tag, file })`, or `cb(nil)` when the cursor isn't inside a
-- component tag (native element, plain markup, or unknown selector). Async only
-- on a cache miss (one rg for the selector's file); a warm selector is sync.
-- Resolve the component tag under the cursor to its member list + meta, with no
-- value-context gate. Async only on a selector cache miss. Internal helper for
-- both attribute-name and attribute-value completion.
local function tag_inputs(cb)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "typescript" then return cb(nil) end
  local tag = enclosing_tag_name(buf)
  if not tag or not tag:find("%-") then return cb(nil) end -- native el / none

  local cached = sel_file_cache[tag]
  if cached ~= nil then
    if not cached then return cb(nil) end
    return cb(inputs_for_file(cached), { tag = tag, file = cached })
  end

  local root = search_root(vim.api.nvim_buf_get_name(buf))
  rg_run(selector_patterns(tag), { root }, function(defs)
    local file = defs[1] and defs[1].file
    sel_file_cache[tag] = file or false
    if not file then return cb(nil) end
    cb(inputs_for_file(file), { tag = tag, file = file })
  end)
end

-- Attribute-NAME completion: the component's inputs/outputs. Suppressed once the
-- cursor is inside a quoted value, where a value expression belongs instead.
function M.component_inputs(cb)
  if in_attr_value(vim.api.nvim_get_current_buf()) then return cb(nil) end
  tag_inputs(cb)
end

-- The attribute whose value the cursor is inside: its input name (brackets
-- stripped) and whether it's a property binding (`[x]="…"`) vs static (`x="…"`).
local function value_attr(buf)
  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buf, math.max(0, pos[1] - 30), pos[1], false)
  if #lines == 0 then return nil end
  lines[#lines] = lines[#lines]:sub(1, pos[2])
  local text = table.concat(lines, "\n")
  local lt = text:find("<[^<>]*$")
  if not lt then return nil end
  local br, attr = text:sub(lt):match("(%[?)([%w%-]+)%]?%s*=%s*['\"][^'\"]*$")
  if not attr then return nil end
  return attr, br == "["
end

-- Attribute-VALUE completion: when the cursor is inside a component input's value
-- and that input's type is an enum or a string/number-literal union, call
-- `cb(spec, meta)` where spec is { kind="enum", enum, en } or
-- { kind="union", values, is_binding }; else `cb(nil)`.
function M.template_value_completions(cb)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "typescript" then return cb(nil) end
  if not in_attr_value(buf) then return cb(nil) end
  local attr, is_binding = value_attr(buf)
  if not attr then return cb(nil) end
  tag_inputs(function(inputs, meta)
    if not inputs then return cb(nil) end
    local input
    for _, it in ipairs(inputs) do
      if it.name == attr then input = it break end
    end
    if not input or not input.type then return cb(nil) end
    local cls = classify_type(input.type)
    if not cls then return cb(nil) end
    if cls.kind == "union" then -- literal union written inline in the annotation
      return cb({ kind = "union", values = cls.values, is_binding = is_binding }, meta)
    end
    -- Named type: resolve to an enum (members) or a type-alias literal union.
    M.resolve_type(cls.name, function(t)
      if not t then return cb(nil) end
      if t.kind == "enum" then
        if #t.members == 0 then return cb(nil) end
        cb({ kind = "enum", enum = t.name, en = t }, meta)
      else
        cb({ kind = "union", values = t.values, is_binding = is_binding }, meta)
      end
    end)
  end)
end

-- Enum-member completion inside a template: when the cursor sits right after
-- `SomeEnum.` in an inline template and `SomeEnum` resolves to an exported enum,
-- call `cb(members, name, enumInfo)` (enumInfo = { file, spec, members }); else
-- `cb(nil)`. Gated to templates so it never doubles up on tsserver, which
-- completes enum members itself in real TS code (and treats the template as an
-- opaque string, offering nothing there).
function M.template_enum_members(cb)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "typescript" then return cb(nil) end
  if not in_template(buf) then return cb(nil) end
  local pos = vim.api.nvim_win_get_cursor(0)
  local before = vim.api.nvim_get_current_line():sub(1, pos[2])
  local enum = before:match("([%u][%w_]*)%.[%w_]*$") -- `Enum.` or `Enum.partial`
  if not enum then return cb(nil) end
  M.resolve_enum(enum, function(en)
    if not en or #en.members == 0 then return cb(nil) end
    cb(en.members, enum, en)
  end)
end

-- ── setup ──────────────────────────────────────────────────────────────────
-- Angular selector navigation on TypeScript buffers (treesitter + rg, no LSP).
-- Not GAF-gated: available in any Angular project. GAF-only features live in
-- lua/gaf/. Buffer-local `gd` shadows the global snacks `gd` on TS buffers, and
-- falls back to LSP definition when the cursor isn't on an Angular target.
--   <leader>cp -> parent components (callers that use this selector, "up")
--   gd         -> definition under cursor: tag (component), attr (@Input/@Output),
--                 class (scss), a symbol in a binding expression (its TS def), or
--                 a template-local (@if `as`, @for var, @let, #ref) binding site;
--                 falls back to LSP definition on plain TS
--   <leader>cG -> prompt for a component name (class or selector) -> its definition
--   <leader>cR -> URL string under cursor -> routing module that handles it
function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("angular_nav", { clear = true }),
    pattern = "typescript",
    callback = function(ev)
      vim.keymap.set("n", "<leader>cp", M.goto_parents,
        { buffer = ev.buf, desc = "Angular: go to parent components" })
      vim.keymap.set("n", "gd", function()
        if not M.goto_definition() then
          Snacks.picker.lsp_definitions()
        end
      end, { buffer = ev.buf, desc = "Go to definition (Angular template-aware)" })
      vim.keymap.set("n", "<leader>cG", M.goto_component_prompt,
        { buffer = ev.buf, desc = "Angular: go to component by name" })
      vim.keymap.set("n", "<leader>cR", M.goto_route,
        { buffer = ev.buf, desc = "Angular: go to route module for URL" })
    end,
  })
end

return M
