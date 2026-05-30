-- webdom: a DevTools "Elements" style panel. Consumer of util.webclient.
--
--   ┌─ element tree ─────────────────────┬─ selected node ───────────────┐
--   │ ▾ <html>                           │ <div id="app" class="card">    │
--   │   ▾ <body>                         │                                │
--   │     ▸ <div id="app" class="card">  │ Attributes                     │
--   │       "hello world"                │   id   : app                   │
--   │     <!-- a comment -->             │   class: card                  │
--   │                                    │                                │
--   │                                    │ Computed Styles                │
--   │                                    │   color      : rgb(0,0,0)      │
--   │                                    │   display    : block           │
--   └─────────────────────────────────────┴────────────────────────────────┘
--
-- The Go bridge serves a lazy DOM tree (`dom_doc` on open, `dom_children` to
-- expand), live attribute/class editing (`dom_set_attr`/`dom_remove_attr`),
-- outerHTML editing (`dom_set_html`) and per-node computed styles (`dom_styles`).
-- Selecting a node in the LEFT tree fetches its styles and fills the RIGHT
-- detail pane (attributes + computed styles). The legacy selector → outerHTML
-- query (`dom_query`/`dom_result`) is kept only as the `inspect` fallback when
-- a selector resolves to a node that isn't in the loaded tree.

local client = require("util.webclient")

local M = {}

-- CDP nodeType constants we special-case in rendering.
local ELEMENT, TEXT, COMMENT, DOCUMENT = 1, 3, 8, 9

local state = {
  tree_buf = nil,
  detail_buf = nil,
  tree_win = nil,
  detail_win = nil,
  registered = false,

  reqid = 0, -- monotonically increasing request id
  gen = 0, -- dom_doc generation counter (bumped each full (re)load).
  -- DOM.getDocument invalidates ALL previously-handed-out nodeIds, so every
  -- nodeId is only valid within the generation it was first seen in. Replies
  -- (children/styles) issued against an older generation are dropped.
  pending_doc = nil, -- reqid we expect a dom_doc reply for (nil = none)
  pending_children = {}, -- reqid -> { nodeId=…, gen=… } we asked to expand
  pending_styles = nil, -- reqid we expect a dom_styles reply for
  pending_styles_node = nil, -- nodeId the in-flight styles request is for
  pending_styles_gen = nil, -- generation the in-flight styles request belongs to

  root = nil, -- root node of the loaded tree
  by_id = {}, -- nodeId -> node (for fast lookup after edits)
  rows = {}, -- tree line -> node
  selected = nil, -- nodeId of the currently-selected node
  styles = {}, -- nodeId -> { {name,value}, ... } (last fetched computed styles)
  styles_loading = nil, -- nodeId we're currently fetching styles for

  pending_edit = {}, -- reqid -> edit descriptor (optimistic in-place apply on ack)

  -- DETAIL pane line maps (rebuilt on every render_detail):
  --   detail_attr_rows: lnum -> attribute name (only Attributes lines; used by `d`)
  --   detail_kv: lnum -> { k=<name>, v=<value> } for BOTH the Attributes and the
  --   Computed Styles lines (used by yk/yv/yb copy).
  detail_attr_rows = {},
  detail_kv = {},

  stale = false, -- tree is stale (navigation) and needs a refresh
  disconnected = false, -- connection dropped
  want_select = nil, -- nodeId to select/reveal once the tree (re)loads (inspect)
  want_path = nil, -- structural path to re-reveal after a refresh (no nodeId)

  -- Find (DevTools-style search). Active search lives in `state.search`:
  --   { query=, count=, matches=, cur=, reqid=, match_ids={[nodeId]=true,…},
  --     walk={ path=, step=, node=, nodeId=, waiting_node= } | nil }
  -- `count` is the total matches in the whole DOM (matches[] is capped at 100);
  -- `match_ids` is the highlight lookup; `walk` is the in-flight async reveal.
  search = nil, -- active search (nil = none)
  pending_search = nil, -- reqid we expect a dom_search reply for (nil = none)
  search_resume = nil, -- query to re-run after a navigation/refresh (re-highlight)
}

local ns = vim.api.nvim_create_namespace("webdom")
-- a dedicated namespace for Find match line-highlights so they can be added /
-- cleared independently of the per-token syntax extmarks (which live in `ns`).
local match_ns = vim.api.nvim_create_namespace("webdom_match")
local COLLAPSED, EXPANDED, LEAF = "▸ ", "▾ ", "  "
-- highlight groups for Find: every match line gets MATCH_HL, the current match
-- gets the stronger MATCH_CUR_HL on top.
local MATCH_HL, MATCH_CUR_HL = "Search", "CurSearch"

local register_handlers -- forward decl (M.inspect references it before its body)

-- ── small helpers ───────────────────────────────────────────────────────────

local function set_lines(buf, lines)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function trunc(s, n)
  s = (s or ""):gsub("[\r\n]", " ")
  if #s > n then
    return s:sub(1, n - 1) .. "…"
  end
  return s
end

-- find an attribute value in a node's flat attr pairs ([["name","val"],...]).
local function attr_get(node, name)
  for _, pair in ipairs(node.attrs or {}) do
    if pair[1] == name then
      return pair[2]
    end
  end
  return nil
end

-- index a (sub)tree into state.by_id so edits/lookups can find nodes by id.
-- Also records `_parent` on every node so optimistic in-place edits (notably
-- element removal) can walk back up to splice the node out of its parent.
local function index_node(node, parent)
  if not node then
    return
  end
  node._parent = parent
  if node.nodeId then
    state.by_id[node.nodeId] = node
  end
  for _, c in ipairs(node.children or {}) do
    index_node(c, node)
  end
end

-- ── render: left tree ───────────────────────────────────────────────────────

-- does a node have children we can lazily fetch (childCount>0, none loaded)?
local function has_lazy_children(node)
  return (node.childCount or 0) > 0 and (not node.children or #node.children == 0)
end

local function is_expandable(node)
  return (node.childCount or 0) > 0 or (node.children and #node.children > 0)
end

-- the open-tag text for an element node: `<tag id="…" class="…" attr=…>`.
-- id/class are shown inline verbatim; other attrs are abbreviated.
local function element_label(node)
  local parts = { "<" .. node.name }
  local id = attr_get(node, "id")
  local cls = attr_get(node, "class")
  if id then
    parts[#parts + 1] = string.format('id="%s"', id)
  end
  if cls then
    parts[#parts + 1] = string.format('class="%s"', trunc(cls, 40))
  end
  -- abbreviate any other attributes (just their names, value clipped short).
  for _, pair in ipairs(node.attrs or {}) do
    local n, v = pair[1], pair[2]
    if n ~= "id" and n ~= "class" then
      if v == nil or v == "" then
        parts[#parts + 1] = n
      else
        parts[#parts + 1] = string.format('%s="%s"', n, trunc(v, 16))
      end
    end
  end
  return table.concat(parts, " ") .. ">"
end

-- a one-line representation of any node + the highlight group to colour it.
local function node_label(node)
  local t = node.type
  if t == ELEMENT then
    return element_label(node), "Identifier"
  elseif t == TEXT then
    local txt = vim.trim(node.value or "")
    if txt == "" then
      return nil, nil -- whitespace-only text node: skip
    end
    return '"' .. trunc(txt, 60) .. '"', "String"
  elseif t == COMMENT then
    return "<!-- " .. trunc(vim.trim(node.value or ""), 50) .. " -->", "Comment"
  elseif t == DOCUMENT then
    return "#document", "Title"
  else
    -- doctype / cdata / other: show the name.
    return "<" .. (node.name or "?") .. ">", "Comment"
  end
end

-- recursively push a node (and, if expanded, its loaded children) into ctx.
local function render_node(ctx, node, depth)
  local label, hl = node_label(node)
  if not label then
    return -- skipped (e.g. whitespace text)
  end
  local marker
  if is_expandable(node) then
    marker = (node.expanded or node.loading) and EXPANDED or COLLAPSED
  else
    marker = LEAF
  end
  local indent = string.rep("  ", depth)
  ctx.lines[#ctx.lines + 1] = indent .. marker .. label
  ctx.hls[#ctx.lines] = { col = #indent + #marker, hl = hl }
  ctx.rows[#ctx.lines] = node
  if node.expanded and node.children then
    for _, c in ipairs(node.children) do
      render_node(ctx, c, depth + 1)
    end
  end
end

local function render_tree(keep_cursor)
  local buf = state.tree_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local ctx = { lines = {}, hls = {}, rows = {} }
  if state.disconnected then
    ctx.lines = { "  (disconnected — r to refresh)" }
  elseif not state.root then
    ctx.lines = { "  (loading DOM…)" }
  else
    -- render children of the document root directly (skip the #document line).
    if state.root.children and #state.root.children > 0 then
      for _, c in ipairs(state.root.children) do
        render_node(ctx, c, 0)
      end
    else
      render_node(ctx, state.root, 0)
    end
    if #ctx.lines == 0 then
      ctx.lines = { "  (empty document)" }
    end
    if state.stale then
      table.insert(ctx.lines, 1, "  (stale — page navigated, r to refresh)")
      -- shift the row/hl maps down by one to match the prepended notice line.
      local rows, hls = {}, {}
      for i, n in pairs(ctx.rows) do
        rows[i + 1] = n
      end
      for i, h in pairs(ctx.hls) do
        hls[i + 1] = h
      end
      ctx.rows, ctx.hls = rows, hls
    end
  end

  state.rows = ctx.rows
  local cur = keep_cursor and state.tree_win and vim.api.nvim_win_is_valid(state.tree_win)
    and vim.api.nvim_win_get_cursor(state.tree_win) or nil
  set_lines(buf, ctx.lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, h in pairs(ctx.hls) do
    if h and h.hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, h.col, { end_col = #ctx.lines[i], hl_group = h.hl })
    end
  end
  -- Find: line-highlight every match row (and the current match more strongly).
  vim.api.nvim_buf_clear_namespace(buf, match_ns, 0, -1)
  if state.search and state.search.match_ids then
    local cur_id = state.search.matches
      and state.search.cur
      and state.search.matches[state.search.cur]
      and state.search.matches[state.search.cur].nodeId
    for i, n in pairs(ctx.rows) do
      if n and n.nodeId and state.search.match_ids[n.nodeId] then
        local grp = (n.nodeId == cur_id) and MATCH_CUR_HL or MATCH_HL
        -- line_hl_group highlights the WHOLE screen line (no end position
        -- needed); a zero-width hl_group+hl_eol extmark colours nothing.
        vim.api.nvim_buf_set_extmark(buf, match_ns, i - 1, 0, { line_hl_group = grp, priority = 200 })
      end
    end
  end
  if cur then
    local maxl = vim.api.nvim_buf_line_count(buf)
    pcall(vim.api.nvim_win_set_cursor, state.tree_win, { math.min(cur[1], maxl), cur[2] })
  end
end

-- ── render: right detail (attributes + computed styles) ─────────────────────

local function push_d(ctx, line, marks)
  ctx.lines[#ctx.lines + 1] = line
  ctx.marks[#ctx.lines] = marks
end

-- build the aligned `name : value` computed-style rows (sorted by name), with
-- name→Identifier / value→String extmark spans. Mirrors the old styles pane.
local function append_styles(ctx, styles)
  push_d(ctx, "", nil)
  push_d(ctx, "Computed Styles", { { 0, -1, "Title" } })
  if type(styles) ~= "table" or #styles == 0 then
    push_d(ctx, "  (no computed styles)", { { 0, -1, "Comment" } })
    return
  end
  local rows = {}
  for _, s in ipairs(styles) do
    rows[#rows + 1] = { name = s.name or "", value = s.value or "" }
  end
  table.sort(rows, function(a, b)
    return a.name < b.name
  end)
  local width = 0
  for _, r in ipairs(rows) do
    if #r.name > width then
      width = #r.name
    end
  end
  for _, r in ipairs(rows) do
    local namepad = "  " .. r.name .. string.rep(" ", width - #r.name)
    local line = namepad .. " : " .. r.value
    local val_start = #namepad + 3
    push_d(ctx, line, {
      { 2, 2 + #r.name, "Identifier" },
      { val_start, #line, "String" },
    })
    -- remember this style line's name/value for the yk/yv/yb copy keys.
    if ctx.kv_rows then
      ctx.kv_rows[#ctx.lines] = { k = r.name, v = r.value }
    end
  end
end

-- list each attribute as a `name: value` row (name→Identifier, value→String).
local function append_attrs(ctx, node)
  push_d(ctx, "Attributes", { { 0, -1, "Title" } })
  local attrs = node.attrs or {}
  if #attrs == 0 then
    push_d(ctx, "  (no attributes)", { { 0, -1, "Comment" } })
    return
  end
  local width = 0
  for _, pair in ipairs(attrs) do
    if #pair[1] > width then
      width = #pair[1]
    end
  end
  for _, pair in ipairs(attrs) do
    local name, val = pair[1], pair[2] or ""
    local namepad = "  " .. name .. string.rep(" ", width - #name)
    local line = namepad .. " : " .. val
    local val_start = #namepad + 3
    push_d(ctx, line, {
      { 2, 2 + #name, "Identifier" },
      { val_start, #line, "String" },
    })
    -- remember which attribute this detail line maps to (for `d` in detail pane).
    ctx.attr_rows[#ctx.lines] = name
    -- and its name/value for the yk/yv/yb copy keys.
    if ctx.kv_rows then
      ctx.kv_rows[#ctx.lines] = { k = name, v = val }
    end
  end
end

local function render_detail()
  local buf = state.detail_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local ctx = { lines = {}, marks = {}, attr_rows = {}, kv_rows = {} }
  local node = state.selected and state.by_id[state.selected]
  if not node then
    push_d(ctx, "  (select a node in the tree)", { { 0, -1, "Comment" } })
  else
    local label = node_label(node) or (node.name or "?")
    push_d(ctx, label, { { 0, -1, "Title" } })
    push_d(ctx, "", nil)
    if node.type == ELEMENT then
      append_attrs(ctx, node)
    end
    -- computed styles only really apply to elements; show the section anyway so
    -- the loading/empty state is visible.
    if node.type == ELEMENT then
      if state.styles_loading == node.nodeId and not state.styles[node.nodeId] then
        push_d(ctx, "", nil)
        push_d(ctx, "Computed Styles", { { 0, -1, "Title" } })
        push_d(ctx, "  (loading…)", { { 0, -1, "Comment" } })
      else
        append_styles(ctx, state.styles[node.nodeId] or {})
      end
    end
  end

  state.detail_attr_rows = ctx.attr_rows
  state.detail_kv = ctx.kv_rows
  set_lines(buf, ctx.lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, marks in pairs(ctx.marks) do
    for _, m in ipairs(marks or {}) do
      local s, e = m[1], m[2]
      if e == -1 then
        e = #ctx.lines[i]
      end
      if e > s then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s, { end_col = e, hl_group = m[3] })
      end
    end
  end
end

-- ── fetch / send ────────────────────────────────────────────────────────────

local function next_reqid()
  state.reqid = state.reqid + 1
  return state.reqid
end

-- a nodeId is usable for a CDP request only if it's truthy and non-zero. A
-- nodeId of 0 is the bridge's placeholder for a not-yet-pushed node and any
-- request against it is doomed ("Could not find node with given id").
local function valid_node_id(id)
  return id ~= nil and id ~= 0
end

-- does a bridge error look like a stale/invalidated/missing nodeId? These come
-- from CDP after DOM.getDocument re-syncs the node map ("Could not find node
-- with given id"). When we see one, the right fix is a full tree refresh.
local function is_stale_node_error(err)
  err = tostring(err or ""):lower()
  return err:find("find node", 1, true) ~= nil
    or err:find("given id", 1, true) ~= nil
    or err:find("node with", 1, true) ~= nil
    or err:find("nodeid", 1, true) ~= nil
    or err:find("no node", 1, true) ~= nil
end

-- request the full document tree (depth 2). Bumps the generation so every
-- nodeId from a previous load is treated as stale, and resets pending state.
-- `keep_path` (optional) is a structural path captured *before* the refresh to
-- re-reveal afterwards (nodeIds can't survive the re-sync, so we use structure).
local function fetch_doc(keep_path)
  state.disconnected = false
  state.gen = state.gen + 1
  if keep_path ~= nil then
    state.want_path = keep_path
  end
  -- in-flight children/styles replies now belong to an older generation and
  -- will be ignored on arrival; clear the tables so they don't leak.
  state.pending_children = {}
  state.pending_styles = nil
  state.pending_styles_node = nil
  state.pending_styles_gen = nil
  state.styles_loading = nil
  -- in-flight edits reference now-invalid nodeIds; drop them (the doc reload
  -- supersedes any optimistic apply they'd attempt).
  state.pending_edit = {}
  client.ensure(function()
    local id = next_reqid()
    state.pending_doc = id
    client.send({ op = "dom_doc", reqid = id, depth = 2 })
  end)
end

-- lazily fetch one node's children. Guards against a falsy/0 nodeId (stale or
-- not-yet-pushed) by refreshing the whole doc instead of sending a doomed
-- request. Tags the request with the current generation.
local function fetch_children(node)
  if not node then
    return
  end
  if not valid_node_id(node.nodeId) then
    node.loading = nil
    node.expanded = false
    vim.notify("webdom: stale node id — refreshing tree", vim.log.levels.WARN)
    fetch_doc()
    return
  end
  client.ensure(function()
    local id = next_reqid()
    state.pending_children[id] = { nodeId = node.nodeId, gen = state.gen }
    client.send({ op = "dom_children", reqid = id, nodeId = node.nodeId })
  end)
end

-- request computed styles for a node (debounced: skip if already in flight or
-- already cached for that node). Falsy/0 nodeIds are skipped silently (styles
-- are best-effort; we don't want passive cursor movement to trigger refreshes).
local function fetch_styles(node)
  if not node or node.type ~= ELEMENT or not valid_node_id(node.nodeId) then
    return
  end
  if state.styles[node.nodeId] or state.styles_loading == node.nodeId then
    return
  end
  client.ensure(function()
    local id = next_reqid()
    state.pending_styles = id
    state.pending_styles_node = node.nodeId
    state.pending_styles_gen = state.gen
    state.styles_loading = node.nodeId
    client.send({ op = "dom_styles", reqid = id, nodeId = node.nodeId })
  end)
end

-- the node under the cursor in the tree pane (nil if none / off the map).
local function node_under_cursor()
  if not (state.tree_win and vim.api.nvim_win_is_valid(state.tree_win)) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.tree_win)[1]
  return state.rows[row]
end

-- select the node under the tree cursor: update the detail pane + fetch styles.
-- Debounced by nodeId so passive cursor movement onto the same node is a no-op.
local function select_under_cursor()
  local node = node_under_cursor()
  if not node then
    return
  end
  if state.selected ~= node.nodeId then
    state.selected = node.nodeId
    render_detail()
    fetch_styles(node)
  end
end

-- ── tree navigation: expand / collapse ──────────────────────────────────────

local function toggle_node()
  local node = node_under_cursor()
  if not node or not is_expandable(node) then
    return
  end
  if node.expanded then
    node.expanded = false -- collapse: cached children are kept for this gen
    node.loading = nil
    render_tree(true)
    return
  end
  node.expanded = true
  if has_lazy_children(node) then
    -- guard against a stale/0 nodeId before sending; if invalid, fetch_children
    -- triggers a full refresh and clears expanded/loading itself.
    if not valid_node_id(node.nodeId) then
      fetch_children(node)
      return
    end
    node.loading = true -- (a) mark loading so a later reply/retry can clear it
    fetch_children(node) -- (b) children arrive via dom_children and re-render
    render_tree(true) -- show the open marker immediately
  else
    render_tree(true)
  end
end

-- expand the whole chain from the root to a target node (used by inspect to
-- reveal a node). Returns true if the node was found in the loaded tree.
local function expand_to(target_id)
  local function walk(node, path)
    if node.nodeId == target_id then
      return path
    end
    for _, c in ipairs(node.children or {}) do
      local r = walk(c, vim.list_extend(vim.deepcopy(path), { c }))
      if r then
        return r
      end
    end
    return nil
  end
  if not state.root then
    return false
  end
  local path = walk(state.root, {})
  if not path then
    return false
  end
  for _, n in ipairs(path) do
    if is_expandable(n) then
      n.expanded = true
    end
  end
  return true
end

-- ── structural-path cursor preservation (survives a nodeId re-sync) ──────────
--
-- nodeIds are invalidated by every dom_doc, so we can't track the user's place
-- by nodeId across a refresh. Instead we record a structural path from the root
-- as a list of { name, index } steps (sibling index within the parent's
-- children), then re-walk that path in the freshly-built tree afterwards.

-- build the structural path (root → node) for `target_id` in the loaded tree.
local function path_of(target_id)
  local result
  local function walk(node, path)
    if node.nodeId == target_id then
      result = path
      return true
    end
    local idx = 0
    for _, c in ipairs(node.children or {}) do
      idx = idx + 1
      local step = { name = c.name or c.value or tostring(c.type), index = idx, type = c.type }
      local next_path = vim.list_extend(vim.deepcopy(path), { step })
      if walk(c, next_path) then
        return true
      end
    end
    return false
  end
  if not state.root then
    return nil
  end
  walk(state.root, {})
  return result
end

-- follow a structural path in the (possibly rebuilt) tree, expanding each step
-- and lazily fetching children when needed. Returns the matched node, or the
-- deepest node we could reach. Best-effort: structure may have changed.
local function follow_path(path)
  local node = state.root
  if not node or not path then
    return node
  end
  for _, step in ipairs(path) do
    if is_expandable(node) then
      node.expanded = true
    end
    local children = node.children or {}
    local match
    -- prefer the same sibling index when the tag matches; else first tag match.
    local byidx = children[step.index]
    if byidx and (byidx.name == step.name and byidx.type == step.type) then
      match = byidx
    else
      for _, c in ipairs(children) do
        if c.type == step.type and (c.name or c.value or tostring(c.type)) == step.name then
          match = c
          break
        end
      end
    end
    if not match then
      return node -- diverged: stop at the deepest reachable node.
    end
    node = match
  end
  return node
end

-- after a rebuild, move the cursor onto `node` (by re-rendering and scanning the
-- row map for object identity) and select it. Best-effort.
local function reveal_path_node(node)
  if not node then
    render_tree(true)
    return
  end
  if is_expandable(node) then
    node.expanded = true
  end
  render_tree(false)
  for line, n in pairs(state.rows) do
    if n == node then
      if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
        pcall(vim.api.nvim_win_set_cursor, state.tree_win, { line, 0 })
      end
      if valid_node_id(node.nodeId) then
        state.selected = node.nodeId
        render_detail()
        fetch_styles(node)
      end
      return
    end
  end
end

-- move the cursor onto the line for `target_id` (if present) and select it.
local function reveal_node(target_id)
  render_tree(false)
  for line, node in pairs(state.rows) do
    if node.nodeId == target_id then
      if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
        pcall(vim.api.nvim_win_set_cursor, state.tree_win, { line, 0 })
      end
      state.selected = target_id
      render_detail()
      fetch_styles(node)
      return true
    end
  end
  return false
end

-- ── edits ───────────────────────────────────────────────────────────────────

-- set/replace `name=value` in a node's flat attr pairs (append if absent).
local function node_set_attr(node, name, value)
  for _, pair in ipairs(node.attrs or {}) do
    if pair[1] == name then
      pair[2] = value
      return
    end
  end
  node.attrs = node.attrs or {}
  node.attrs[#node.attrs + 1] = { name, value }
end

-- drop `name` from a node's flat attr pairs (no-op if absent).
local function node_remove_attr(node, name)
  if not node.attrs then
    return
  end
  for i, pair in ipairs(node.attrs) do
    if pair[1] == name then
      table.remove(node.attrs, i)
      return
    end
  end
end

-- recursively drop a node (and its descendants) from state.by_id + styles.
local function deindex_node(node)
  if not node then
    return
  end
  if node.nodeId then
    state.by_id[node.nodeId] = nil
    state.styles[node.nodeId] = nil
  end
  for _, c in ipairs(node.children or {}) do
    deindex_node(c)
  end
end

-- splice `node` out of its parent's children (optimistic element removal). Picks
-- a sane sibling/parent to land the tree cursor on, then re-renders both panes.
local function apply_remove_node(node)
  local parent = node._parent
  if not parent or not parent.children then
    -- no parent link (e.g. root or unindexed): fall back to a doc refresh.
    fetch_doc(node.nodeId and path_of(node.nodeId) or nil)
    return
  end
  local idx
  for i, c in ipairs(parent.children) do
    if c == node then
      idx = i
      break
    end
  end
  if not idx then
    fetch_doc()
    return
  end
  table.remove(parent.children, idx)
  parent.childCount = math.max(0, (parent.childCount or 1) - 1)
  deindex_node(node)
  -- pick the node to land the cursor/selection on: prefer a sibling, else parent.
  local landing = parent.children[idx] or parent.children[idx - 1] or parent
  -- clear selection/styles if they pointed at the removed node.
  if state.selected == node.nodeId then
    state.selected = nil
  end
  if node.nodeId then
    state.styles[node.nodeId] = nil
  end
  render_tree(false)
  -- move the tree cursor onto the landing node (best-effort) + select it.
  for line, n in pairs(state.rows) do
    if n == landing then
      if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
        pcall(vim.api.nvim_win_set_cursor, state.tree_win, { line, 0 })
      end
      if landing.type == ELEMENT and valid_node_id(landing.nodeId) then
        state.selected = landing.nodeId
        fetch_styles(landing)
      end
      break
    end
  end
  render_detail()
end

-- after an edit acks, re-fetch the affected node's children (or the whole doc)
-- so the tree/attrs reflect the change. Cursor is kept near the edited node.
-- Obeys the same generation/stale-id rules as any other refresh: an outerHTML
-- edit reloads the node's children *within the current generation*; an attr
-- edit re-reads the whole doc (bumping the generation) and re-reveals the node
-- by structural path, since its old nodeId won't survive the re-sync.
local function refresh_after_edit(node_id)
  local node = node_id and valid_node_id(node_id) and state.by_id[node_id]
  -- drop cached styles for the edited node so they re-fetch.
  if node_id then
    state.styles[node_id] = nil
  end
  if node and node.expanded and (node.childCount or 0) > 0 then
    -- the node's subtree may have changed (outerHTML edit) — reload its children
    -- in place (same generation, nodeId still valid).
    node.children = nil
    node.loading = true
    fetch_children(node)
    state.want_select = node_id -- valid within this generation.
  else
    -- structural change / unknown node: re-read the whole doc (bumps gen) and
    -- restore the user's place by structure, not by the now-invalid nodeId.
    local keep = node_id and path_of(node_id) or nil
    fetch_doc(keep)
  end
end

local function send_set_attr(node_id, name, value)
  local id = next_reqid()
  state.last_edit_node = node_id
  -- record the descriptor BEFORE sending so the ack can apply it optimistically.
  state.pending_edit[id] = { kind = "attr", node_id = node_id, name = name, value = value }
  client.send({ op = "dom_set_attr", reqid = id, nodeId = node_id, name = name, value = value })
end

local function edit_class()
  local node = node_under_cursor()
  if not node or node.type ~= ELEMENT then
    vim.notify("webdom: select an element first", vim.log.levels.WARN)
    return
  end
  local cur = attr_get(node, "class") or ""
  vim.ui.input({ prompt = "class = ", default = cur }, function(v)
    if v == nil then
      return
    end
    send_set_attr(node.nodeId, "class", v)
  end)
end

local function edit_attr()
  local node = node_under_cursor()
  if not node or node.type ~= ELEMENT then
    vim.notify("webdom: select an element first", vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "attribute name: " }, function(name)
    if not name or name == "" then
      return
    end
    local cur = attr_get(node, name) or ""
    vim.ui.input({ prompt = name .. " = ", default = cur }, function(v)
      if v == nil then
        return
      end
      send_set_attr(node.nodeId, name, v)
    end)
  end)
end

-- send a remove-attr op for `name` on `node`, recording the pending_edit
-- descriptor so the ack updates the cached node in place (no fetch).
local function send_remove_attr(node, name)
  local id = next_reqid()
  state.last_edit_node = node.nodeId
  state.pending_edit[id] = { kind = "remove_attr", node_id = node.nodeId, name = name }
  client.send({ op = "dom_remove_attr", reqid = id, nodeId = node.nodeId, name = name })
end

-- DETAIL pane: remove the attribute on the line under the cursor (no typing).
-- Confirms first, then sends with an optimistic descriptor.
local function remove_attr()
  local node = state.selected and state.by_id[state.selected]
  if not node then
    vim.notify("webdom: select a node first", vim.log.levels.WARN)
    return
  end
  if not (state.detail_win and vim.api.nvim_win_is_valid(state.detail_win)) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(state.detail_win)[1]
  local name = state.detail_attr_rows and state.detail_attr_rows[row]
  if not name then
    vim.notify("webdom: put the cursor on an attribute line", vim.log.levels.WARN)
    return
  end
  if vim.fn.confirm("Remove attribute '" .. name .. "'?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  send_remove_attr(node, name)
end

-- DETAIL pane: the { k=<name>, v=<value> } for the line under the cursor, or nil
-- when the cursor sits on a header / blank / non-kv line.
local function kv_under_cursor()
  if not (state.detail_win and vim.api.nvim_win_is_valid(state.detail_win)) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.detail_win)[1]
  return state.detail_kv and state.detail_kv[row]
end

-- copy `text` to both the system clipboard (+) and the unnamed (") register,
-- with a short truncated confirmation. `what` labels the notify (e.g. "key").
local function copy_to_registers(text, what)
  text = text or ""
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.notify("webdom: copied " .. what .. ": " .. trunc(text, 60), vim.log.levels.INFO)
end

-- DETAIL pane: copy the NAME / VALUE / BOTH of the attribute or computed-style
-- line under the cursor. `mode` is "k", "v" or "b". Soft no-op off a kv line.
local function copy_kv(mode)
  local kv = kv_under_cursor()
  if not kv then
    vim.notify("webdom: put the cursor on an attribute or style line", vim.log.levels.WARN)
    return
  end
  if mode == "k" then
    copy_to_registers(kv.k or "", "key")
  elseif mode == "v" then
    copy_to_registers(kv.v or "", "value")
  else
    copy_to_registers((kv.k or "") .. ": " .. (kv.v or ""), "both")
  end
end

-- TREE pane: remove an attribute from the node under the cursor by PICKING it
-- from a list (no typing). One attr → skip the picker; confirms before sending.
local function remove_attr_pick()
  local node = node_under_cursor()
  if not node or node.type ~= ELEMENT then
    vim.notify("webdom: select an element first", vim.log.levels.WARN)
    return
  end
  local names = {}
  for _, pair in ipairs(node.attrs or {}) do
    names[#names + 1] = pair[1]
  end
  if #names == 0 then
    vim.notify("webdom: node has no attributes", vim.log.levels.WARN)
    return
  end
  local function confirm_and_send(name)
    if vim.fn.confirm("Remove attribute '" .. name .. "'?", "&Yes\n&No", 2) ~= 1 then
      return
    end
    send_remove_attr(node, name)
  end
  if #names == 1 then
    confirm_and_send(names[1])
    return
  end
  vim.ui.select(names, { prompt = "Remove attribute:" }, function(name)
    if not name then
      return
    end
    confirm_and_send(name)
  end)
end

-- TREE pane: delete the element under the cursor (DOM.removeNode). Targets an
-- element node, confirms, then sends with an optimistic remove_node descriptor.
local function delete_element()
  local node = node_under_cursor()
  if not node or node.type ~= ELEMENT then
    vim.notify("webdom: select an element first", vim.log.levels.WARN)
    return
  end
  if not valid_node_id(node.nodeId) then
    vim.notify("webdom: stale node id — refresh first", vim.log.levels.WARN)
    return
  end
  if vim.fn.confirm("Delete <" .. (node.name or "?") .. ">?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  local id = next_reqid()
  state.last_edit_node = node.nodeId
  state.pending_edit[id] = { kind = "remove_node", node_id = node.nodeId }
  client.send({ op = "dom_remove_node", reqid = id, nodeId = node.nodeId })
end

-- reconstruct the element's open tag from its name + attrs. Full outerHTML isn't
-- available client-side (the tree only carries the open-tag shape), so the
-- scratch buffer is seeded best-effort with `<tag attr="val" …></tag>` for the
-- element + any already-loaded children rendered as their own tags. On save we
-- send the whole edited text as the node's new outerHTML.
local function reconstruct_open_tag(node)
  local parts = { "<" .. node.name }
  for _, pair in ipairs(node.attrs or {}) do
    local n, v = pair[1], pair[2]
    if v == nil or v == "" then
      parts[#parts + 1] = n
    else
      parts[#parts + 1] = string.format('%s="%s"', n, (v:gsub('"', "&quot;")))
    end
  end
  return table.concat(parts, " ") .. ">"
end

-- void elements have no closing tag — keep the reconstructed HTML valid.
local VOID = {
  area = true, base = true, br = true, col = true, embed = true, hr = true,
  img = true, input = true, link = true, meta = true, param = true,
  source = true, track = true, wbr = true,
}

local function reconstruct_outer_html(node)
  local open = reconstruct_open_tag(node)
  if VOID[node.name] then
    return { open }
  end
  local lines = { open }
  -- include any loaded children verbatim-ish so the edit isn't destructive of
  -- simple text content; this is best-effort, not a faithful serializer.
  for _, c in ipairs(node.children or {}) do
    if c.type == TEXT then
      local t = vim.trim(c.value or "")
      if t ~= "" then
        lines[#lines + 1] = "  " .. t
      end
    elseif c.type == ELEMENT then
      lines[#lines + 1] = "  " .. reconstruct_open_tag(c) .. (VOID[c.name] and "" or ("</" .. c.name .. ">"))
    elseif c.type == COMMENT then
      lines[#lines + 1] = "  <!-- " .. vim.trim(c.value or "") .. " -->"
    end
  end
  lines[#lines + 1] = "</" .. node.name .. ">"
  return lines
end

local function edit_outer_html()
  local node = node_under_cursor()
  if not node or node.type ~= ELEMENT then
    vim.notify("webdom: select an element first", vim.log.levels.WARN)
    return
  end
  local node_id = node.nodeId
  local lines = reconstruct_outer_html(node)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "html"
  vim.api.nvim_buf_set_name(buf, "ChromeDOM://outerHTML/" .. node_id)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false

  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, math.min(20, math.max(6, #lines + 2)))
  vim.wo[win].winbar = "  edit outerHTML <" .. node.name .. ">  (:w or <CR> to save · q to cancel)"

  local committed = false
  local function commit()
    if committed then
      return
    end
    committed = true
    local html = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local id = next_reqid()
    state.last_edit_node = node_id
    state.pending_edit[id] = { kind = "html", node_id = node_id }
    client.send({ op = "dom_set_html", reqid = id, nodeId = node_id, html = html })
    vim.bo[buf].modified = false
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  vim.keymap.set("n", "<CR>", commit, { buffer = buf, desc = "Save outerHTML" })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end, { buffer = buf, desc = "Cancel" })
  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = commit })
end

-- ── Find (DevTools-style search) ─────────────────────────────────────────────

-- the base tree winbar (no active search). Kept in sync with M.open().
local TREE_WINBAR =
  "  Elements  (<CR> expand · / find · n/N match · d del · x rm attr · c class · A attr · e html · r refresh · i inspect · ? help · q close)"

-- recompute the tree window's winbar to reflect the current Find state:
--   no search          → the base hint
--   searching…         → `… (searching…)`
--   active w/ matches   → `Find "<q>"  k/N` (or `k/N of TOTAL` when capped)
--   active, no matches  → `Find "<q>"  0 matches`
local function update_winbar(searching)
  local win = state.tree_win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local bar
  if searching then
    bar = "  Elements  (searching…)"
  elseif state.search then
    local s = state.search
    local n = #s.matches
    if n == 0 then
      bar = string.format('  Find "%s"  0 matches  (<Esc> clear)', s.query)
    else
      local pos = string.format("%d/%d", s.cur, n)
      if (s.count or n) > n then
        pos = pos .. " of " .. tostring(s.count)
      end
      bar = string.format('  Find "%s"  %s  (n/N next/prev · <Esc> clear)', s.query, pos)
    end
  else
    bar = TREE_WINBAR
  end
  vim.wo[win].winbar = bar
end

local advance_walk -- forward decl (finish_walk / dom_children handler reference it)

-- conclude an in-flight reveal walk. On success the target row should now be
-- visible (ancestors expanded); move the cursor there + select it + fetch
-- styles. On failure, fall back to showing the match's details by nodeId.
local function finish_walk(ok)
  local search = state.search
  if not search then
    return
  end
  local walk = search.walk
  search.walk = nil
  if not walk then
    return
  end
  render_tree(true)
  if ok and walk.node then
    local target = walk.node
    for line, n in pairs(state.rows) do
      if n == target then
        if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
          pcall(vim.api.nvim_win_set_cursor, state.tree_win, { line, 0 })
        end
        break
      end
    end
    state.selected = target.nodeId
    render_detail()
    fetch_styles(target)
  else
    -- couldn't reveal in the tree (index mismatch, shadow/pseudo, missing node):
    -- still surface the match in the detail pane using the search-reported id.
    if valid_node_id(walk.nodeId) then
      state.selected = walk.nodeId
      render_detail()
      local n = state.by_id[walk.nodeId]
      if n then
        fetch_styles(n)
      end
    end
    vim.notify("webdom: couldn't reveal match in tree (showing details)", vim.log.levels.WARN)
  end
  -- repaint match highlights now the current match / expansions changed.
  render_tree(true)
end

-- drive the async reveal walk: descend `walk.path` from the tree root, lazily
-- expanding each level. When a level needs a fetch, mark it + RETURN; the
-- dom_children handler resumes us once the children arrive.
advance_walk = function()
  local search = state.search
  if not search then
    return
  end
  local walk = search.walk
  if not walk then
    return
  end
  while walk.step <= #walk.path do
    local node = walk.node
    if not node then
      return finish_walk(false)
    end
    if has_lazy_children(node) then
      -- children not loaded yet: expand + fetch, then wait for dom_children.
      if not valid_node_id(node.nodeId) then
        return finish_walk(false)
      end
      node.expanded = true
      node.loading = true
      walk.waiting_node = node
      fetch_children(node)
      render_tree(true)
      return
    end
    node.expanded = true
    local idx = walk.path[walk.step]
    -- path is 0-based (childNodes indices from the bridge); Lua tables are
    -- 1-based, so add 1.
    local child = node.children and node.children[idx + 1]
    if child == nil then
      return finish_walk(false)
    end
    walk.node = child
    walk.step = walk.step + 1
  end
  finish_walk(true)
end

-- reveal match `i` (1-based into state.search.matches) by walking its path from
-- the tree root. Kicks off the async walker.
local function jump_to_match(i)
  local search = state.search
  if not search or not search.matches then
    return
  end
  local match = search.matches[i]
  if not match then
    return
  end
  search.cur = i
  if not state.root then
    -- nothing loaded to walk into: fall back to detail-only.
    if valid_node_id(match.nodeId) then
      state.selected = match.nodeId
      render_detail()
    end
    update_winbar(false)
    return
  end
  search.walk = { path = match.path or {}, step = 1, node = state.root, nodeId = match.nodeId }
  advance_walk()
  update_winbar(false)
end

-- clear any active search: drop state, wipe match highlights, re-render.
local function clear_search()
  if not state.search then
    return
  end
  state.search = nil
  state.pending_search = nil
  render_tree(true)
  update_winbar(false)
end

-- `/` in the tree pane: prompt for a query and dispatch a dom_search. Empty /
-- cancelled input clears any active search.
local function find_prompt()
  vim.ui.input({
    prompt = "Find (text/selector): ",
    default = (state.search and state.search.query) or "",
  }, function(q)
    if not q or q == "" then
      clear_search()
      return
    end
    client.ensure(function()
      local id = next_reqid()
      state.pending_search = id
      update_winbar(true) -- show "(searching…)" until the reply lands.
      client.send({ op = "dom_search", reqid = id, query = q })
    end)
  end)
end

-- `n` / `N`: jump to the next / previous match, wrapping. Soft no-op when there
-- is no active search with matches.
local function find_next(prev)
  local search = state.search
  if not search or #search.matches == 0 then
    vim.notify("webdom: no active search (press / to find)", vim.log.levels.INFO)
    return
  end
  local n = #search.matches
  local cur = search.cur or 1
  if prev then
    cur = ((cur - 2) % n) + 1
  else
    cur = (cur % n) + 1
  end
  jump_to_match(cur)
end

-- ── inspect by selector ─────────────────────────────────────────────────────

-- prompt a CSS selector, open the panel, resolve it via the bridge's
-- dom_query, then try to reveal the matching node in the loaded tree. If it
-- isn't loaded, fall back to showing its outerHTML + styles in the detail pane.
function M.inspect()
  register_handlers()
  vim.ui.input({ prompt = "Inspect selector: ", default = state.last_selector or "" }, function(sel)
    if not sel or sel == "" then
      return
    end
    state.last_selector = sel
    if not (state.tree_win and vim.api.nvim_win_is_valid(state.tree_win)) then
      M.open()
    end
    client.ensure(function()
      local id = next_reqid()
      state.pending_query = id
      client.send({ op = "dom_query", reqid = id, selector = sel })
    end)
  end)
end

-- ── help float ──────────────────────────────────────────────────────────────

local HELP_LINES = {
  "  webdom — Elements panel keys",
  "",
  "  Tree pane:",
  "    <CR>/<Tab>  expand / collapse (lazy fetch)",
  "    /           find (text / selector)",
  "    n / N       next / previous match",
  "    <Esc>       clear the search",
  "    d           delete element (confirm)",
  "    x           remove attribute (pick, confirm)",
  "    c           edit the class value",
  "    A           add / edit an attribute value",
  "    e           edit outerHTML in a scratch split",
  "    r           refresh the tree",
  "    i           inspect by CSS selector",
  "    <S-Tab>     jump to detail pane",
  "    ?           this help",
  "    q           close panel",
  "",
  "  Detail pane:",
  "    d           remove the attribute under the cursor",
  "    yk          copy the key (attr/style name) under the cursor",
  "    yv          copy the value under the cursor",
  "    yb          copy both as `key: value`",
  "    <Tab>       jump to tree pane",
  "    q           close panel",
}

local function show_help()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP_LINES)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local width = 0
  for _, l in ipairs(HELP_LINES) do
    width = math.max(width, #l)
  end
  local height = #HELP_LINES
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2)),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Elements help ",
  })
  vim.wo[win].cursorline = false
  for _, k in ipairs({ "q", "<Esc>", "?" }) do
    vim.keymap.set("n", k, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })
  end
end

-- ── handlers ─────────────────────────────────────────────────────────────────

register_handlers = function()
  if state.registered then
    return
  end
  state.registered = true

  -- full document tree.
  client.on("dom_doc", function(ev)
    if state.pending_doc == nil or ev.reqid ~= state.pending_doc then
      return -- stale / foreign reply
    end
    state.pending_doc = nil
    if not ev.ok then
      state.root = nil
      render_tree(false)
      vim.notify("webdom: dom_doc failed: " .. (ev.error or "?"), vim.log.levels.ERROR)
      return
    end
    -- DOM.getDocument invalidated every nodeId we held: fully rebuild from the
    -- new tree and DROP all cached children/expanded/styles tied to old ids.
    -- We do NOT merge old nodeIds into the new tree — they're meaningless now.
    local want_path, want_select = state.want_path, state.want_select
    state.want_path, state.want_select = nil, nil
    state.root = ev.root
    state.by_id = {}
    state.styles = {} -- styles were keyed by now-invalid nodeIds.
    state.styles_loading = nil
    state.selected = nil
    index_node(state.root)
    state.stale = false
    state.disconnected = false
    -- a refetch invalidates the search's match nodeIds/paths: drop the stale
    -- RESULTS (highlights clear on the next render_tree). But preserve the
    -- QUERY so we can re-run it against the fresh tree and re-highlight — search
    -- persists across navigation/refresh, like DevTools. Crucially, do NOT clear
    -- state.pending_search: an in-flight dom_search issued for the new page must
    -- still be allowed to complete (clearing it here was dropping post-navigation
    -- searches as "foreign replies" → no highlight).
    local resume_query = (state.search and state.search.query) or state.search_resume
    state.search_resume = nil
    state.search = nil
    -- baseline expansion: the document root, plus the first element level
    -- (html/body) so the tree isn't a single collapsed line on (re)load.
    if state.root then
      state.root.expanded = true
      for _, c in ipairs(state.root.children or {}) do
        if c.type == ELEMENT then
          c.expanded = true
        end
      end
    end
    -- re-run a persisted search against the freshly-loaded tree so matches
    -- re-highlight after a navigation / refresh. Skip if a dom_search is already
    -- in flight (don't stack), or if nothing to resume.
    if resume_query and resume_query ~= "" and not state.pending_search then
      local sid = next_reqid()
      state.pending_search = sid
      client.send({ op = "dom_search", reqid = sid, query = resume_query })
    end
    -- restore the user's place by structure (tag + sibling index), since the
    -- old nodeId is gone. follow_path expands the chain best-effort.
    if want_path then
      local node = follow_path(want_path)
      reveal_path_node(node)
      return
    end
    -- a queued inspect target: reveal it (expanding the chain to it). This is
    -- valid within the *new* generation only (expand_to walks the fresh tree).
    if want_select then
      if expand_to(want_select) and reveal_node(want_select) then
        return
      end
    end
    render_tree(true)
  end)

  -- lazily-loaded children for one node.
  client.on("dom_children", function(ev)
    local pend = state.pending_children[ev.reqid]
    if pend == nil then
      return -- stale / foreign reply
    end
    state.pending_children[ev.reqid] = nil
    -- (c) ignore replies issued against an older dom_doc generation: their
    -- nodeId is invalid now and the matching node may not even exist.
    if pend.gen ~= state.gen then
      return
    end
    local node = state.by_id[pend.nodeId]
    if not node then
      return
    end
    node.loading = nil -- clear loading regardless of outcome (retry-able).
    if not ev.ok then
      -- the bridge couldn't find the node. If it smells like a stale/missing
      -- nodeId, re-sync the whole tree (nodeIds were invalidated); otherwise
      -- just leave the node collapsed so a later <CR> can retry.
      local err = tostring(ev.error or "")
      vim.notify("webdom: expand failed: " .. (err ~= "" and err or "?"), vim.log.levels.WARN)
      node.expanded = false
      -- a Find reveal walk waiting on this node can't continue: bail to the
      -- detail-only fallback. Skip if we're about to refresh (fetch_doc clears
      -- the search and would make finish_walk's render redundant/wrong).
      if state.search and state.search.walk and state.search.walk.waiting_node == node then
        state.search.walk.waiting_node = nil
        if not is_stale_node_error(err) then
          finish_walk(false)
        end
      end
      if is_stale_node_error(err) then
        fetch_doc(path_of(pend.nodeId)) -- refresh + keep place by structure.
      else
        render_tree(true)
      end
      return
    end
    node.children = ev.children or {}
    for _, c in ipairs(node.children) do
      index_node(c, node)
    end
    -- (d) childCount said >0 but no children came back: treat as a leaf so we
    -- don't leave a ▸ marker that never opens. has_lazy_children() now returns
    -- false (children is a non-nil empty table) and is_expandable() too.
    if (node.childCount or 0) > 0 and #node.children == 0 then
      node.childCount = 0
      node.expanded = false
    end
    -- if an inspect target lives under here, keep expanding toward it.
    if state.want_select and expand_to(state.want_select) then
      local target = state.want_select
      if reveal_node(target) then
        state.want_select = nil
        return
      end
    end
    -- a Find reveal walk waiting on this node can now continue descending.
    if state.search and state.search.walk and state.search.walk.waiting_node == node then
      state.search.walk.waiting_node = nil
      advance_walk()
      return
    end
    render_tree(true)
  end)

  -- computed styles for the in-flight node.
  client.on("dom_styles", function(ev)
    if state.pending_styles == nil or ev.reqid ~= state.pending_styles then
      return -- stale / foreign reply
    end
    local req_gen = state.pending_styles_gen
    local node_id = state.pending_styles_node
    state.pending_styles = nil
    state.pending_styles_node = nil
    state.pending_styles_gen = nil
    if state.styles_loading == node_id then
      state.styles_loading = nil
    end
    -- drop replies whose request belonged to an older generation: the nodeId is
    -- invalid now and caching styles under it would be wrong.
    if req_gen ~= state.gen then
      return
    end
    if not ev.ok then
      return -- styles are best-effort; a missing-node error just shows empty.
    end
    state.styles[ev.nodeId or node_id] = ev.styles or {}
    if state.selected == (ev.nodeId or node_id) then
      render_detail()
    end
  end)

  -- Find: result of a dom_search. Store the matches, jump to the first, and
  -- update the winbar with the k/N position counter.
  client.on("dom_search", function(ev)
    if state.pending_search == nil or ev.reqid ~= state.pending_search then
      return -- stale / foreign reply
    end
    state.pending_search = nil
    if not ev.ok then
      vim.notify("webdom: search failed: " .. (ev.error or "?"), vim.log.levels.ERROR)
      update_winbar(false)
      return
    end
    local matches = ev.matches or {}
    local match_ids = {}
    for _, m in ipairs(matches) do
      if m.nodeId then
        match_ids[m.nodeId] = true
      end
    end
    state.search = {
      query = ev.query or "",
      count = ev.count or #matches,
      matches = matches,
      cur = 0,
      reqid = ev.reqid,
      match_ids = match_ids,
    }
    if #matches == 0 then
      render_tree(true) -- clears any stale highlights from a previous search.
      update_winbar(false)
      vim.notify("webdom: no matches", vim.log.levels.INFO)
      return
    end
    jump_to_match(1)
  end)

  -- ack of an edit (set/remove attr, set html, remove node). Applies the change
  -- OPTIMISTICALLY + in place to the cached node (correlated by reqid via
  -- state.pending_edit) so edits appear instantly without collapsing the tree.
  client.on("dom_set", function(ev)
    local edit = state.pending_edit[ev.reqid]
    if edit then
      state.pending_edit[ev.reqid] = nil
    end
    local node_id = (edit and edit.node_id) or ev.nodeId or state.last_edit_node

    if not ev.ok then
      local err = tostring(ev.error or "")
      vim.notify("webdom: edit failed: " .. (err ~= "" and err or "?"), vim.log.levels.ERROR)
      -- a stale/missing nodeId on edit means our tree is out of sync: re-read
      -- the doc (gen bump) keeping the user's place by structure.
      if is_stale_node_error(err) then
        fetch_doc(node_id and path_of(node_id) or nil)
      end
      return
    end

    -- older code path / unknown reqid: fall back to the legacy refresh.
    if not edit then
      refresh_after_edit(node_id)
      return
    end

    if edit.kind == "html" then
      -- outerHTML can replace the node (and change its nodeId), so a targeted
      -- subtree reload is correct. Reload the parent's children in place when
      -- possible; otherwise refresh the doc keeping the user's place.
      local node = state.by_id[edit.node_id]
      local parent = node and node._parent
      if parent and valid_node_id(parent.nodeId) and parent.expanded then
        state.styles[edit.node_id] = nil
        parent.children = nil
        parent.loading = true
        fetch_children(parent)
      else
        fetch_doc(path_of(edit.node_id))
      end
      return
    end

    -- attr / remove_attr / remove_node: mutate the CACHED node directly.
    local node = state.by_id[edit.node_id]
    if not node then
      -- the cached node vanished (out-of-sync): refresh keeping place.
      fetch_doc(edit.node_id and path_of(edit.node_id) or nil)
      return
    end

    if edit.kind == "attr" then
      node_set_attr(node, edit.name, edit.value)
      render_tree(true) -- updates the inline `<tag class=…>` line.
      if state.selected == edit.node_id then
        render_detail() -- updates the Attributes section.
      end
    elseif edit.kind == "remove_attr" then
      node_remove_attr(node, edit.name)
      render_tree(true)
      if state.selected == edit.node_id then
        render_detail()
      end
    elseif edit.kind == "remove_node" then
      apply_remove_node(node)
    end
  end)

  -- inspect fallback: dom_query resolved a selector → outerHTML + styles. If the
  -- node is already in our tree we'd have revealed it; here we just show its
  -- outerHTML + styles in the detail pane as a best-effort fallback.
  client.on("dom_result", function(ev)
    if state.pending_query == nil or ev.reqid ~= state.pending_query then
      return
    end
    state.pending_query = nil
    local buf = state.detail_buf
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      return
    end
    if not ev.ok then
      vim.notify("webdom: no match for selector: " .. (ev.error or "?"), vim.log.levels.WARN)
      return
    end
    -- show the matched element's outerHTML + computed styles in the detail pane.
    state.selected = nil -- not a tree node
    local ctx = { lines = {}, marks = {}, attr_rows = {}, kv_rows = {} }
    push_d(ctx, "(selector match — not in loaded tree)", { { 0, -1, "Comment" } })
    push_d(ctx, "", nil)
    push_d(ctx, "outerHTML", { { 0, -1, "Title" } })
    for _, l in ipairs(vim.split(ev.html or "", "\n", { plain = true })) do
      push_d(ctx, "  " .. l, nil)
    end
    append_styles(ctx, ev.styles or {})
    state.detail_attr_rows = ctx.attr_rows
    state.detail_kv = ctx.kv_rows
    set_lines(buf, ctx.lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, marks in pairs(ctx.marks) do
      for _, m in ipairs(marks or {}) do
        local s, e = m[1], m[2]
        if e == -1 then
          e = #ctx.lines[i]
        end
        if e > s then
          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s, { end_col = e, hl_group = m[3] })
        end
      end
    end
  end)

  -- navigation invalidates the tree (and every nodeId): mark stale + drop all
  -- caches + auto-refresh if visible. want_path/want_select from a prior tree
  -- are meaningless across a navigation, so clear them too.
  client.on("navigated", function()
    state.pending_doc = nil
    state.pending_children = {}
    state.pending_styles = nil
    state.pending_styles_node = nil
    state.pending_styles_gen = nil
    state.pending_edit = {}
    state.styles = {}
    state.styles_loading = nil
    state.want_path = nil
    state.want_select = nil
    -- match nodeIds/paths from the old tree are meaningless across a navigation,
    -- but remember the QUERY so the post-nav dom_doc re-runs + re-highlights it.
    state.search_resume = (state.search and state.search.query) or state.search_resume
    state.search = nil
    state.pending_search = nil
    state.stale = true
    if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
      fetch_doc()
    end
  end)

  -- (re)attach: refresh against the new target if the panel is open.
  client.on("ready", function()
    state.disconnected = false
    if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
      fetch_doc()
    end
  end)

  client.on("closed", function()
    state.disconnected = true
    state.pending_doc = nil
    state.pending_children = {}
    state.pending_styles = nil
    state.pending_styles_node = nil
    state.pending_styles_gen = nil
    state.pending_edit = {}
    state.styles_loading = nil
    -- the disconnect invalidates the tree + every match nodeId; drop the search.
    state.search = nil
    state.pending_search = nil
    if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
      render_tree(false)
    end
  end)
end

-- ── windows / buffers ────────────────────────────────────────────────────────

local function tree_map(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  map("<CR>", toggle_node, "Expand/collapse node")
  map("<Tab>", toggle_node, "Expand/collapse node")
  map("c", edit_class, "Edit class attribute")
  map("A", edit_attr, "Add/edit attribute")
  map("d", delete_element, "Delete element")
  map("x", remove_attr_pick, "Remove attribute (pick)")
  map("e", edit_outer_html, "Edit outerHTML")
  map("r", function()
    -- manual refresh: re-sync nodeIds but keep the user's place by structure.
    local n = node_under_cursor()
    fetch_doc(n and valid_node_id(n.nodeId) and path_of(n.nodeId) or nil)
  end, "Refresh tree")
  map("i", M.inspect, "Inspect by selector")
  map("/", find_prompt, "Find (text/selector)")
  map("n", function()
    find_next(false)
  end, "Next match")
  map("N", function()
    find_next(true)
  end, "Previous match")
  map("<Esc>", clear_search, "Clear search")
  map("?", show_help, "Help")
  map("q", M.close, "Close")
  map("<S-Tab>", function()
    if state.detail_win and vim.api.nvim_win_is_valid(state.detail_win) then
      vim.api.nvim_set_current_win(state.detail_win)
    end
  end, "Go to detail")
end

local function detail_map(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  map("d", remove_attr, "Remove attribute under cursor")
  map("yk", function()
    copy_kv("k")
  end, "Copy key under cursor")
  map("yv", function()
    copy_kv("v")
  end, "Copy value under cursor")
  map("yb", function()
    copy_kv("b")
  end, "Copy key: value under cursor")
  map("?", show_help, "Help")
  map("q", M.close, "Close")
  map("<Tab>", function()
    if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
      vim.api.nvim_set_current_win(state.tree_win)
    end
  end, "Go to tree")
end

local function ensure_bufs()
  if not (state.tree_buf and vim.api.nvim_buf_is_valid(state.tree_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeDOM")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webdom"
    vim.bo[buf].modifiable = false
    tree_map(buf)
    -- passive cursor movement selects the node + fetches its styles (debounced).
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = buf,
      callback = function()
        if vim.api.nvim_get_current_win() == state.tree_win then
          select_under_cursor()
        end
      end,
    })
    state.tree_buf = buf
  end
  if not (state.detail_buf and vim.api.nvim_buf_is_valid(state.detail_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeDOMDetail")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webdomdetail"
    vim.bo[buf].modifiable = false
    detail_map(buf)
    state.detail_buf = buf
  end
end

-- open fullscreen in a dedicated tab (tree left / detail right). Buffers + state
-- persist across close, so toggling is cheap and lossless.
function M.open()
  ensure_bufs()
  if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
    vim.api.nvim_set_current_win(state.tree_win)
    return
  end
  vim.cmd("tabnew")
  state.tree_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.tree_win, state.tree_buf)
  vim.wo[state.tree_win].number = false
  vim.wo[state.tree_win].relativenumber = false
  vim.wo[state.tree_win].wrap = false
  vim.wo[state.tree_win].cursorline = true
  vim.wo[state.tree_win].winbar = TREE_WINBAR

  vim.cmd("rightbelow vsplit")
  state.detail_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.detail_win, state.detail_buf)
  vim.wo[state.detail_win].number = false
  vim.wo[state.detail_win].relativenumber = false
  vim.wo[state.detail_win].wrap = false
  vim.wo[state.detail_win].winbar =
    "  Selected node  (yk/yv/yb copy key/value/both · d remove attr · <Tab> tree)"

  render_tree(false)
  render_detail()
  update_winbar(false) -- reflect any search that survived a close/reopen.
  vim.api.nvim_set_current_win(state.tree_win)

  -- (re)load the tree if we have nothing or it's stale.
  if not state.root or state.stale then
    fetch_doc()
  end
end

-- close both windows (tab collapses); buffers + state are kept.
function M.close()
  for _, w in ipairs({ state.detail_win, state.tree_win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  state.tree_win, state.detail_win = nil, nil
end

function M.toggle()
  register_handlers()
  if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
    M.close()
  else
    M.open()
  end
end

-- ── public API ──────────────────────────────────────────────────────────────

function M.start()
  register_handlers()
  M.open()
end

function M.stop()
  M.close()
end

return M
