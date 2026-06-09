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

return M
