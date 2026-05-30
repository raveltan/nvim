-- webstorage: a DevTools "Application" style storage panel. Consumer of
-- util.webclient.
--
--   ┌─ scopes ──────┬─ key / value ─────────────────────────────┐
--   │ ▸ localStorage │ token   "eyJ…"                            │
--   │   sessionStor. │ theme   "dark"                            │
--   │   cookies      │  (e edit · d delete · a add · C clear)    │
--   └────────────────┴────────────────────────────────────────────┘
--
-- localStorage/sessionStorage: read + edit + delete + add + clear.
-- cookies: read + edit + delete + add.

local client = require("util.webclient")

local M = {}

local SCOPES = {
  { label = "localStorage", kind = "local" },
  { label = "sessionStorage", kind = "session" },
  { label = "cookies", kind = "cookies" },
  { label = "IndexedDB", kind = "indexeddb" },
  { label = "Cache Storage", kind = "cachestorage" },
}

local function read_only(kind)
  kind = kind or nil
  return kind == "indexeddb" or kind == "cachestorage"
end

local state = {
  selected = 1, -- index into SCOPES
  items = {}, -- local/session: {{key,value}...}; cookies: {cookie-table...}
  tree = nil, -- indexeddb/cachestorage: read-only json tree root
  rows = {}, -- kv line -> item
  filter = nil, -- active substring filter on key/name, or nil
  scopes_buf = nil,
  kv_buf = nil,
  scopes_win = nil,
  kv_win = nil,
  registered = false,
}

local ns = vim.api.nvim_create_namespace("webstorage")
local OPEN, CLOSED = "▸ ", "  "

local fetch -- forward declaration (refetch_soon references it)

local function cur()
  return SCOPES[state.selected]
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function trunc(s, n)
  s = (s or ""):gsub("\n", "⏎")
  if #s > n then
    return s:sub(1, n - 1) .. "…"
  end
  return s
end

-- schedule a refetch shortly after a mutating send so the panel reflects the
-- change without a manual R (the bridge also re-emits, this guards races).
local function refetch_soon()
  vim.defer_fn(function()
    if state.kv_win and vim.api.nvim_win_is_valid(state.kv_win) then
      fetch()
    end
  end, 120)
end

-- ── fetch ─────────────────────────────────────────────────────────────────

fetch = function()
  client.ensure(function()
    if cur().kind ~= "cookies" then
      client.enable("dom_storage")
    end
    client.send({ op = "storage_get", kind = cur().kind })
  end)
end

-- ── render ─────────────────────────────────────────────────────────────────

local function render_scopes()
  local buf = state.scopes_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, hls = {}, {}
  for i, s in ipairs(SCOPES) do
    lines[i] = (i == state.selected and OPEN or CLOSED) .. s.label
    hls[i] = (i == state.selected) and "Title" or "Normal"
  end
  set_lines(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #lines[i], hl_group = hl })
  end
end

local function expires_str(c)
  if c.session or not c.expires or c.expires < 0 then
    return "session"
  end
  return os.date("%Y-%m-%d", math.floor(c.expires))
end

local function cookie_flags(c)
  local f = {}
  if c.httpOnly then f[#f + 1] = "HttpOnly" end
  if c.secure then f[#f + 1] = "Secure" end
  if c.sameSite then f[#f + 1] = c.sameSite end
  return table.concat(f, ",")
end

-- client-side JSON tree (storage values are raw strings; parse + expand them)
local function scalar_str(v)
  if v == nil or v == vim.NIL then
    return "null"
  elseif type(v) == "string" then
    return '"' .. v .. '"'
  else
    return tostring(v)
  end
end

-- highlight group for a scalar's rendered text (shared by tree + flat render)
local function scalar_hl(text)
  if text:sub(1, 1) == '"' then
    return "String"
  elseif text == "true" or text == "false" then
    return "Boolean"
  elseif text == "null" then
    return "Comment"
  else
    return "Number"
  end
end

local function json_node(key, val)
  local n = { key = key }
  if type(val) == "table" and val ~= vim.NIL then
    n.container = true
    n.is_array = vim.islist(val)
    n.value = val
    n.expanded = false
    local c = 0
    for _ in pairs(val) do
      c = c + 1
    end
    n.text = n.is_array and ("Array(" .. c .. ")") or "{…}"
  else
    n.container = false
    n.text = scalar_str(val)
  end
  return n
end

local function children_of(n)
  if n._children then
    return n._children
  end
  local cs = {}
  if n.is_array then
    for i, v in ipairs(n.value) do
      cs[#cs + 1] = json_node(tostring(i - 1), v)
    end
  else
    local ks = {}
    for k in pairs(n.value) do
      ks[#ks + 1] = k
    end
    table.sort(ks)
    for _, k in ipairs(ks) do
      cs[#cs + 1] = json_node(k, n.value[k])
    end
  end
  n._children = cs
  return cs
end

local function push_kv(ctx, line, hl, entry)
  for _, seg in ipairs(vim.split(line, "\n", { plain = true })) do
    ctx.lines[#ctx.lines + 1] = (seg:gsub("\r", ""))
    ctx.hls[#ctx.lines] = hl
    ctx.map[#ctx.lines] = entry
  end
end

local function render_jnode(ctx, n, depth, item)
  local indent = string.rep("  ", depth)
  local marker = n.container and (n.expanded and "▾ " or "▸ ") or "  "
  local namepart = n.key and (n.key .. ": ") or ""
  local hl = n.container and "Identifier" or scalar_hl(n.text)
  push_kv(ctx, indent .. marker .. namepart .. n.text, hl, { item = item, node = n })
  if n.container and n.expanded then
    for _, c in ipairs(children_of(n)) do
      render_jnode(ctx, c, depth + 1, item)
    end
  end
end

-- does an item's key/name pass the active filter?
local function filter_pass(name)
  if not state.filter or state.filter == "" then
    return true
  end
  return (name or ""):lower():find(state.filter:lower(), 1, true) ~= nil
end

local function render_kv()
  local buf = state.kv_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local ctx = { lines = {}, hls = {}, map = {} }
  if read_only(cur().kind) then
    if state.tree then
      render_jnode(ctx, state.tree, 0, nil)
    else
      push_kv(ctx, "  (loading…)", "Comment", nil)
    end
    if #ctx.lines == 0 then
      push_kv(ctx, "  (empty)", "Comment", nil)
    end
    state.kv_map = ctx.map
    set_lines(buf, ctx.lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, hl in pairs(ctx.hls) do
      if hl then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #ctx.lines[i], hl_group = hl })
      end
    end
    if state.kv_win and vim.api.nvim_win_is_valid(state.kv_win) then
      vim.wo[state.kv_win].winbar = "  " .. cur().label .. "  (read-only · <CR>/<Tab> expand · yk/yv/yb copy · R refresh · ? help)"
    end
    return
  end
  if cur().kind == "cookies" then
    push_kv(ctx, string.format("%-22s %-28s %-20s %-6s %-10s %s", "name", "value", "domain", "path", "expires", "flags"), "Title", nil)
    for _, c in ipairs(state.items) do
      if filter_pass(c.name) then
        push_kv(ctx, string.format("%-22s %-28s %-20s %-6s %-10s %s",
          trunc(c.name, 22), trunc(c.value, 28), trunc(c.domain, 20),
          trunc(c.path, 6), expires_str(c), cookie_flags(c)), "Normal", { item = c })
      end
    end
  else
    for _, it in ipairs(state.items) do
      if filter_pass(it.key) then
        if it.node then
          render_jnode(ctx, it.node, 0, it)
        else
          push_kv(ctx, it.key .. ": " .. it.value, "Normal", { item = it })
        end
      end
    end
  end
  if #ctx.lines == 0 or (cur().kind == "cookies" and #ctx.lines == 1) then
    push_kv(ctx, state.filter and ("  (no matches for /" .. state.filter .. ")") or "  (empty)", "Comment", nil)
  end
  state.kv_map = ctx.map
  set_lines(buf, ctx.lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, hl in pairs(ctx.hls) do
    if hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #ctx.lines[i], hl_group = hl })
    end
  end
  if state.kv_win and vim.api.nvim_win_is_valid(state.kv_win) then
    local verb = cur().kind == "cookies" and "(e edit · d delete · a add · yk/yv/yb copy · / filter · R refresh · ? help)"
      or "(<CR> expand/yank · e edit · d delete · a add · C clear · yk/yv/yb copy · / filter · R refresh · ? help)"
    local flt = state.filter and ("  [/" .. state.filter .. "]") or ""
    vim.wo[state.kv_win].winbar = "  " .. cur().label .. flt .. "  " .. verb
  end
end

-- ── actions ─────────────────────────────────────────────────────────────────

local function select_scope()
  local row = vim.api.nvim_win_get_cursor(state.scopes_win or 0)[1]
  if SCOPES[row] and row ~= state.selected then
    state.selected = row
    state.items = {}
    state.tree = nil
    state.filter = nil
    render_scopes()
    render_kv()
    fetch()
  end
end

local function current_entry()
  return state.kv_map and state.kv_map[vim.api.nvim_win_get_cursor(0)[1]]
end

local function current_row_item()
  local e = current_entry()
  return e and e.item
end

-- resolve the cursor line to a {key, value} pair for copying. Works for flat
-- local/session items (key + raw value), cookie rows (name + value), and JSON
-- tree nodes (property name / array index + scalar text or compact JSON for a
-- container). Returns key,value (either may be nil for keyless / valueless rows).
local function current_kv()
  local e = current_entry()
  if not e then
    return nil, nil
  end
  if e.node then
    local n = e.node
    local val
    if n.container then
      local ok, enc = pcall(vim.json.encode, n.value)
      val = ok and enc or n.text
    else
      -- strip the surrounding quotes scalar_str adds to strings; numbers/bools/null verbatim
      val = (type(n.value) == "string") and n.value or (n.text or "")
    end
    return n.key, val
  end
  local it = e.item
  if not it then
    return nil, nil
  end
  if cur().kind == "cookies" then
    return it.name, it.value
  end
  return it.key, it.value
end

-- copy text to both the system (+) and unnamed (") registers
local function setreg_both(s)
  vim.fn.setreg("+", s)
  vim.fn.setreg('"', s)
end

local function deny_ro()
  if read_only(cur().kind) then
    vim.notify(cur().label .. " is read-only", vim.log.levels.WARN)
    return true
  end
  return false
end

-- build the page-relative URL for a cookie so setCookie/deleteCookies target it
local function cookie_url(c)
  local scheme = c.secure and "https" or "http"
  local domain = (c.domain or ""):gsub("^%.", "")
  return scheme .. "://" .. domain .. (c.path or "/")
end

-- pick a representative origin url for a freshly-added cookie, derived from an
-- existing cookie's domain so it lands on the right origin (else nil → bridge
-- falls back to location.href).
local function default_cookie_url()
  for _, c in ipairs(state.items) do
    if c.domain and c.domain ~= "" then
      local scheme = c.secure and "https" or "http"
      return scheme .. "://" .. (c.domain:gsub("^%.", "")) .. "/"
    end
  end
  return nil
end

local function act_delete()
  if deny_ro() then
    return
  end
  local it = current_row_item()
  if not it then
    return
  end
  local label = cur().kind == "cookies" and it.name or it.key
  if vim.fn.confirm("Delete '" .. (label or "?") .. "'?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  if cur().kind == "cookies" then
    if client.send({ op = "cookie_delete", name = it.name, url = cookie_url(it) }) then
      refetch_soon()
    end
  else
    if client.send({ op = "storage_remove", kind = cur().kind, key = it.key }) then
      refetch_soon()
    end
  end
end

-- pretty-print a JSON string into indented lines. Prefers `jq` (handles huge
-- values fast); falls back to vim.json round-trip on one line if jq is absent.
local function pretty_json(value)
  if vim.fn.executable("jq") == 1 then
    local pp = vim.fn.systemlist({ "jq", "." }, value)
    if vim.v.shell_error == 0 and type(pp) == "table" and #pp > 0 then
      return pp
    end
  end
  local ok, enc = pcall(vim.json.encode, vim.json.decode(value))
  if ok then
    return vim.split(enc, "\n", { plain = true })
  end
  return vim.split(value, "\n", { plain = true })
end

-- pretty-print a value if it parses as JSON; else return it unchanged.
local function pretty_or_raw(value)
  local ok = pcall(vim.json.decode, value)
  if ok then
    return pretty_json(value), true
  end
  return vim.split(value or "", "\n", { plain = true }), false
end

-- open a scratch split prefilled with `value`, re-encode/validate on confirm,
-- and call on_commit(text). JSON values are pretty-printed; raw text is edited
-- as-is and re-sent verbatim.
local function open_value_editor(title, value, on_commit)
  local lines, was_json = pretty_or_raw(value)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = was_json and "json" or "text"
  vim.api.nvim_buf_set_name(buf, "ChromeStorage://" .. title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false

  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, math.min(20, math.max(6, #lines + 2)))
  vim.wo[win].winbar = "  edit " .. title .. "  (:w or <CR> to save · q to cancel)"

  local committed = false
  local function commit()
    if committed then
      return
    end
    local txt = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    -- if the buffer parses as JSON, re-encode compactly to validate + normalize;
    -- otherwise send the raw text verbatim.
    local out = txt
    if was_json or txt:match("^%s*[%[{\"]") then
      local ok, dec = pcall(vim.json.decode, txt)
      if not ok then
        vim.notify("storage: invalid JSON, not saved:\n" .. tostring(dec), vim.log.levels.ERROR)
        return
      end
      local ok2, enc = pcall(vim.json.encode, dec)
      if ok2 then
        out = enc
      end
    end
    committed = true
    on_commit(out)
    vim.bo[buf].modified = false
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  vim.keymap.set("n", "<CR>", commit, { buffer = buf, desc = "Save value" })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end, { buffer = buf, desc = "Cancel" })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = commit,
  })
end

local function act_edit()
  if deny_ro() then
    return
  end
  local it = current_row_item()
  if not it then
    return
  end
  if cur().kind == "cookies" then
    vim.ui.input({ prompt = it.name .. " = ", default = it.value }, function(v)
      if v ~= nil then
        if client.send({ op = "cookie_set", name = it.name, value = v, url = cookie_url(it) }) then
          refetch_soon()
        end
      end
    end)
    return
  end
  local kind = cur().kind
  local key = it.key
  open_value_editor(key, it.value or "", function(out)
    if client.send({ op = "storage_set", kind = kind, key = key, value = out }) then
      refetch_soon()
    end
  end)
end

local function act_add()
  if deny_ro() then
    return
  end
  if cur().kind == "cookies" then
    local url = default_cookie_url()
    vim.ui.input({ prompt = "cookie name: " }, function(name)
      if not name or name == "" then
        return
      end
      vim.ui.input({ prompt = name .. " = " }, function(v)
        if v ~= nil then
          local msg = { op = "cookie_set", name = name, value = v }
          if url then
            msg.url = url
          end
          if client.send(msg) then
            refetch_soon()
          end
        end
      end)
    end)
    return
  end
  local kind = cur().kind
  vim.ui.input({ prompt = "new key: " }, function(k)
    if not k or k == "" then
      return
    end
    vim.ui.input({ prompt = k .. " = " }, function(v)
      if v ~= nil then
        if client.send({ op = "storage_set", kind = kind, key = k, value = v }) then
          refetch_soon()
        end
      end
    end)
  end)
end

local function act_clear()
  if deny_ro() then
    return
  end
  if cur().kind == "cookies" then
    vim.notify("use d to delete individual cookies", vim.log.levels.WARN)
    return
  end
  if vim.fn.confirm("Clear all " .. cur().label .. "?", "&Yes\n&No") == 1 then
    if client.send({ op = "storage_clear", kind = cur().kind }) then
      refetch_soon()
    end
  end
end

-- yv: yank the VALUE under the cursor (storage value, cookie value, or JSON
-- scalar / compact JSON for a container) to both + and " registers. Quiet:
-- only a short truncated confirmation, never a multi-line dump.
local function act_yank_value()
  local _, val = current_kv()
  if val == nil then
    vim.notify("storage: no value here", vim.log.levels.WARN)
    return
  end
  setreg_both(val)
  vim.notify("value yanked: " .. trunc(val, 60))
end

-- yk: yank the KEY / cookie-name / JSON property-name under the cursor to both
-- + and " registers.
local function act_yank_key()
  local key = current_kv()
  if not key or key == "" then
    vim.notify("storage: no key here", vim.log.levels.WARN)
    return
  end
  setreg_both(key)
  vim.notify("key yanked: " .. trunc(key, 60))
end

-- yb: yank BOTH as "key: value" to both + and " registers.
local function act_yank_both()
  local key, val = current_kv()
  if key == nil and val == nil then
    vim.notify("storage: nothing to yank here", vim.log.levels.WARN)
    return
  end
  local both = (key or "") .. ": " .. (val or "")
  setreg_both(both)
  vim.notify("yanked: " .. trunc(both, 60))
end

-- /: prompt a substring filter on key/name; a second / with empty input clears.
local function act_filter()
  if read_only(cur().kind) then
    return
  end
  vim.ui.input({ prompt = "filter (key/name): ", default = state.filter or "" }, function(v)
    if v == nil then
      return
    end
    state.filter = (v ~= "" and v) or nil
    render_kv()
  end)
end

-- <CR>: expand/collapse a JSON value node, else yank the full value
local function act_enter()
  local e = current_entry()
  if not e then
    return
  end
  if e.node and e.node.container then
    e.node.expanded = not e.node.expanded
    render_kv()
    return
  end
  act_yank_value()
end

-- ?: help float listing this panel's keys
local function act_help()
  local lines = {
    " Storage panel ",
    "",
    " key/value pane:",
    "   <CR>  expand JSON / yank value",
    "   e     edit value (buffer editor for local/session)",
    "   d     delete item (confirm)",
    "   a     add item",
    "   C     clear all (local/session)",
    "   R     refresh",
    "   /     filter by key/name",
    "   yk    copy key / cookie name / JSON name",
    "   yv    copy value (scalar / compact JSON)",
    "   yb    copy both as key: value",
    "   ?     this help",
    "   q     close panel",
    "",
    " scopes pane:",
    "   <CR>  select scope",
    "   <Tab> jump to values",
    "   q     close panel",
  }
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " webstorage ? ",
  })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end, { buffer = buf })
end

-- ── handlers ─────────────────────────────────────────────────────────────────

local function register_handlers()
  if state.registered then
    return
  end
  state.registered = true

  client.on("storage_items", function(ev)
    if cur().kind ~= ev.kind then
      return
    end
    state.items = {}
    for _, pair in ipairs(ev.items or {}) do
      local it = { key = pair[1], value = pair[2] }
      local ok, dec = pcall(vim.json.decode, it.value)
      if ok and type(dec) == "table" then
        it.node = json_node(it.key, dec)
      end
      state.items[#state.items + 1] = it
    end
    render_kv()
  end)

  client.on("cookies", function(ev)
    if cur().kind ~= "cookies" then
      return
    end
    state.items = ev.cookies or {}
    render_kv()
  end)

  client.on("storage_tree", function(ev)
    if cur().kind ~= ev.kind then
      return
    end
    state.tree = json_node(nil, ev.data or vim.empty_dict())
    state.tree.expanded = true
    render_kv()
  end)

  client.on("storage_error", function(ev)
    vim.notify("storage (" .. (ev.kind or "?") .. "): " .. (ev.error or ""), vim.log.levels.ERROR)
  end)

  -- refetch when the connection (re)attaches, e.g. after :ChromeTabs
  client.on("ready", function()
    if state.scopes_win and vim.api.nvim_win_is_valid(state.scopes_win) then
      fetch()
    end
  end)

  -- page navigation may change origin/storageKey: refetch the current scope.
  client.on("navigated", function()
    if state.scopes_win and vim.api.nvim_win_is_valid(state.scopes_win) then
      state.items = {}
      state.tree = nil
      render_kv()
      fetch()
    end
  end)
end

-- ── windows ─────────────────────────────────────────────────────────────────

local function ensure_bufs()
  if not (state.scopes_buf and vim.api.nvim_buf_is_valid(state.scopes_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeStorage")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webstorage"
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "<CR>", select_scope, { buffer = buf, desc = "Select scope" })
    vim.keymap.set("n", "q", M.close, { buffer = buf, desc = "Close" })
    vim.keymap.set("n", "?", act_help, { buffer = buf, desc = "Help" })
    vim.keymap.set("n", "<Tab>", function()
      if state.kv_win and vim.api.nvim_win_is_valid(state.kv_win) then
        vim.api.nvim_set_current_win(state.kv_win)
      end
    end, { buffer = buf, desc = "Go to values" })
    state.scopes_buf = buf
  end
  if not (state.kv_buf and vim.api.nvim_buf_is_valid(state.kv_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeStorageKV")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webstoragekv"
    vim.bo[buf].modifiable = false
    local function map(lhs, fn, desc)
      vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
    end
    map("R", fetch, "Refresh")
    map("d", act_delete, "Delete")
    map("e", act_edit, "Edit value")
    map("a", act_add, "Add item")
    map("C", act_clear, "Clear all")
    map("/", act_filter, "Filter by key/name")
    map("yk", act_yank_key, "Copy key / name")
    map("yv", act_yank_value, "Copy value")
    map("yb", act_yank_both, "Copy key: value")
    map("?", act_help, "Help")
    map("<CR>", act_enter, "Expand JSON / yank value")
    map("<Tab>", act_enter, "Expand JSON")
    map("q", M.close, "Close")
    state.kv_buf = buf
  end
end

-- open fullscreen in a dedicated tab (scopes left / key-value right).
function M.open()
  ensure_bufs()
  if state.scopes_win and vim.api.nvim_win_is_valid(state.scopes_win) then
    vim.api.nvim_set_current_win(state.scopes_win)
    return
  end
  vim.cmd("tabnew")
  state.scopes_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.scopes_win, state.scopes_buf)
  vim.wo[state.scopes_win].number = false
  vim.wo[state.scopes_win].relativenumber = false
  vim.wo[state.scopes_win].cursorline = true
  vim.wo[state.scopes_win].winbar = "  Storage  (<CR> select · <Tab> values · ? help)"

  vim.cmd("rightbelow vsplit")
  state.kv_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.kv_win, state.kv_buf)
  vim.wo[state.kv_win].number = false
  vim.wo[state.kv_win].relativenumber = false
  vim.wo[state.kv_win].wrap = false

  vim.api.nvim_win_set_width(state.scopes_win, 18)
  render_scopes()
  render_kv()
  vim.api.nvim_set_current_win(state.scopes_win)
end

-- close both windows (tab collapses); buffers + state are kept.
function M.close()
  for _, w in ipairs({ state.kv_win, state.scopes_win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  state.scopes_win, state.kv_win = nil, nil
end

function M.toggle()
  if state.scopes_win and vim.api.nvim_win_is_valid(state.scopes_win) then
    M.close()
  else
    M.start()
  end
end

-- ── public API ──────────────────────────────────────────────────────────

function M.start()
  register_handlers()
  M.open()
  fetch()
end

function M.stop()
  M.close()
end

return M
