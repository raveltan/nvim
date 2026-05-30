-- webnetwork: a DevTools-style Network panel. Consumer of util.webclient.
--
--   ┌─ master (left) ───────────────────────┬─ detail (right) ──────────┐
--   │ started method status type size time  │ General / Headers /        │
--   │ 09:14:02 GET 200 ⚡ fetch 1.2KB 34ms   │ Payload / Response (tree)  │
--   └────────────────────────────────────────┴────────────────────────────┘
--
-- Filter bar: `/` sets a URL substring; NUMBER keys 1-9,0 toggle resource-type
-- filters (1 = All) so hjkl stay free for navigation; `F` cycles a status-class
-- filter (All → errors → 4xx → 5xx). A `⚡` marker flags responses served from
-- the disk cache. Cursor in master highlights/selects a row; the response body
-- is fetched only on an explicit select (`<CR>`/`gd`), not on passive scroll.
-- Press `?` in the list for the full key reference. Navigation/reattach clears
-- the log (DevTools "preserve log" off).

local client = require("util.webclient")

local M = {}

-- resource-type filter buttons -> CDP ResourceType set. Toggled with NUMBER
-- keys (1 = All) so hjkl navigation is never hijacked.
local BUTTONS = {
  { num = "2", label = "XHR", types = { XHR = true, Fetch = true } },
  { num = "3", label = "JS", types = { Script = true } },
  { num = "4", label = "CSS", types = { Stylesheet = true } },
  { num = "5", label = "Img", types = { Image = true } },
  { num = "6", label = "Doc", types = { Document = true } },
  { num = "7", label = "Font", types = { Font = true } },
  { num = "8", label = "Media", types = { Media = true, TextTrack = true } },
  { num = "9", label = "WS", types = { WebSocket = true, EventSource = true } },
  { num = "0", label = "Other", types = {} }, -- everything not covered above
}

-- union of all explicitly-categorised types (anything else = "Other")
local KNOWN = {}
for _, b in ipairs(BUTTONS) do
  for t in pairs(b.types) do
    KNOWN[t] = true
  end
end

-- status-class filter cycle: All → errors(4xx/5xx) → 4xx → 5xx → back to All
local STATUS_FILTERS = {
  { key = "all", label = "All" },
  { key = "err", label = "Errors" },
  { key = "4xx", label = "4xx" },
  { key = "5xx", label = "5xx" },
}

local state = {
  requests = {}, -- ordered list
  by_id = {}, -- requestId -> req
  rows = {}, -- list line -> req
  selected = nil, -- requestId
  reqid = 0,
  pending_body = {}, -- reqid -> requestId
  filter = { url = "", types = {}, status = 1 }, -- types: active button labels; empty = All. status: index into STATUS_FILTERS
  blocked = {}, -- set of blocked URL patterns (pattern -> true)
  detail_nodes = {}, -- detail line -> json node
  detail_kv = {}, -- detail line -> { k = key/name, v = value text } for yk/yv/yb
  list_buf = nil,
  detail_buf = nil,
  list_win = nil,
  detail_win = nil,
  registered = false,
  max = 600,
}

local ns = vim.api.nvim_create_namespace("webnetwork")
local OPEN, CLOSED = "▾ ", "▸ "

-- ── formatting helpers ────────────────────────────────────────────────────

local function human_size(n)
  if not n or n == 0 then
    return "-"
  end
  if n < 1024 then
    return string.format("%dB", n)
  elseif n < 1024 * 1024 then
    return string.format("%.1fKB", n / 1024)
  else
    return string.format("%.1fMB", n / (1024 * 1024))
  end
end

local function duration_str(req)
  if not req.start or not req.done_ts then
    return "-"
  end
  local ms = (req.done_ts - req.start) * 1000
  if ms < 1000 then
    return string.format("%dms", math.floor(ms + 0.5))
  end
  return string.format("%.2fs", ms / 1000)
end

-- format the request's wallTime (Unix epoch seconds, from net_request) as
-- local HH:MM:SS. wallTime is fractional seconds since the epoch.
local function started_str(req)
  if not req.wallTime or req.wallTime <= 0 then
    return "--:--:--"
  end
  return os.date("%H:%M:%S", math.floor(req.wallTime))
end

local function status_str(req)
  if req.failed then
    return req.canceled and "(canc)" or "ERR"
  end
  return req.status and tostring(req.status) or "..."
end

local function status_hl(req)
  if req.failed then
    return "DiagnosticError"
  end
  local s = req.status or 0
  if s >= 500 then
    return "DiagnosticError"
  elseif s >= 400 then
    return "DiagnosticWarn"
  elseif s >= 300 then
    return "DiagnosticInfo"
  elseif s >= 200 then
    return "String"
  end
  return "Comment"
end

local METHOD_HL = { GET = "Identifier", POST = "Function", PUT = "Function", DELETE = "DiagnosticError", PATCH = "Function" }

-- ── filtering ─────────────────────────────────────────────────────────────

local function type_passes(restype)
  local active = state.filter.types
  if next(active) == nil then
    return true
  end
  for _, b in ipairs(BUTTONS) do
    if active[b.label] then
      if b.label == "Other" then
        if not KNOWN[restype] then
          return true
        end
      elseif b.types[restype] then
        return true
      end
    end
  end
  return false
end

-- status-class filter: matches the active STATUS_FILTERS entry against a req.
local function status_passes(req)
  local key = STATUS_FILTERS[state.filter.status].key
  if key == "all" then
    return true
  end
  -- a failed/canceled request counts as an error but has no numeric status
  local s = req.status or 0
  if key == "err" then
    return req.failed or (s >= 400 and s <= 599)
  elseif key == "4xx" then
    return s >= 400 and s <= 499
  elseif key == "5xx" then
    return s >= 500 and s <= 599
  end
  return true
end

local function passes(req)
  if state.filter.url ~= "" and not (req.url or ""):lower():find(state.filter.url:lower(), 1, true) then
    return false
  end
  if not status_passes(req) then
    return false
  end
  return type_passes(req.restype or "Other")
end

-- ── master list render ─────────────────────────────────────────────────────

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function blocked_count()
  local n = 0
  for _ in pairs(state.blocked) do
    n = n + 1
  end
  return n
end

local function filter_winbar()
  local parts = {}

  -- attached tab + connection status
  local att = client.attached()
  local title = att.title ~= "" and att.title or (att.target ~= "" and att.target or "(no tab)")
  if #title > 40 then
    title = title:sub(1, 39) .. "…"
  end
  parts[#parts + 1] = "%#Title#" .. title .. "%* [" .. client.status() .. "]  "

  parts[#parts + 1] = "/=" .. (state.filter.url ~= "" and state.filter.url or "—") .. "  "

  -- status-class filter
  local sf = STATUS_FILTERS[state.filter.status]
  if sf.key == "all" then
    parts[#parts + 1] = "[F:All]  "
  else
    parts[#parts + 1] = "%#WarningMsg#[F:" .. sf.label .. "]%*  "
  end

  -- resource-type filters
  local all_on = next(state.filter.types) == nil
  parts[#parts + 1] = all_on and "%#WarningMsg#[1 All]%*" or "[1 All]"
  for _, b in ipairs(BUTTONS) do
    if state.filter.types[b.label] then
      parts[#parts + 1] = " %#WarningMsg#[" .. b.num .. " " .. b.label .. "]%*"
    else
      parts[#parts + 1] = " [" .. b.num .. " " .. b.label .. "]"
    end
  end

  -- blocked-URL count
  local nb = blocked_count()
  if nb > 0 then
    parts[#parts + 1] = "  %#DiagnosticError#[b:" .. nb .. " blocked]%*"
  end

  return table.concat(parts)
end

local function render_list()
  local buf = state.list_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, hls, rows = {}, {}, {}
  for _, req in ipairs(state.requests) do
    if passes(req) then
      local url = req.url or ""
      -- columns: started(8) method(6) status(5) cache(1) restype(12) size(8) time(8) url
      -- cache marker: ⚡ when served from disk cache, blank otherwise
      local cache = req.fromCache and "⚡" or " "
      local line = string.format("%-8s %-6s %-5s %s %-12s %8s %8s  %s",
        started_str(req), req.method or "?", status_str(req), cache,
        (req.restype or ""):sub(1, 12),
        human_size(req.size), duration_str(req), url)
      lines[#lines + 1] = line
      rows[#rows + 1] = req
      hls[#hls] = nil
      hls[#lines] = { method = METHOD_HL[req.method] or "Keyword", status = status_hl(req) }
    end
  end
  if #lines == 0 then
    lines = { "  (no requests — reload the page to capture)" }
  end
  state.rows = rows
  set_lines(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, h in pairs(hls) do
    -- layout: started(0..7) ' ' method(9..14) ' ' status(16..20) ' ' cache …
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 9, { end_col = 15, hl_group = h.method })
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 16, { end_col = 21, hl_group = h.status })
  end
  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
    vim.wo[state.list_win].winbar = filter_winbar()
  end
end

-- ── detail render (right pane) ─────────────────────────────────────────────

local function scalar_str(v)
  if v == nil or v == vim.NIL then
    return "null"
  elseif type(v) == "string" then
    return '"' .. v .. '"'
  else
    return tostring(v)
  end
end

local function json_node(key, val)
  local n = { key = key }
  if type(val) == "table" and val ~= vim.NIL then
    n.container = true
    n.is_array = vim.islist(val)
    n.value = val
    n.expanded = false
    local cnt = 0
    for _ in pairs(val) do
      cnt = cnt + 1
    end
    n.text = n.is_array and ("Array(" .. cnt .. ")") or "{…}"
  else
    n.container = false
    n.text = scalar_str(val)
  end
  return n
end

local function children_of(node)
  if node._children then
    return node._children
  end
  local cs = {}
  if node.is_array then
    for i, v in ipairs(node.value) do
      cs[#cs + 1] = json_node(tostring(i - 1), v)
    end
  else
    local keys = {}
    for k in pairs(node.value) do
      keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      cs[#cs + 1] = json_node(k, node.value[k])
    end
  end
  node._children = cs
  return cs
end

-- detail render context: items = list of {text,hl} or {node=jsonroot}. `kv` (if
-- given) is a { k=<string>, v=<string> } recorded only against the FIRST output
-- line, so yk/yv/yb can copy the key/value under the cursor.
local function push_d(ctx, line, hl, node, kvrec)
  for k, seg in ipairs(vim.split(line, "\n", { plain = true })) do
    ctx.lines[#ctx.lines + 1] = (seg:gsub("\r", ""))
    ctx.hls[#ctx.lines] = hl
    ctx.map[#ctx.lines] = (k == 1) and node or nil
    ctx.kv[#ctx.lines] = (k == 1) and kvrec or nil
  end
end

-- value text for a JSON node's yk/yv/yb record. Scalars copy their raw text
-- (unquoted strings); containers copy a compact JSON dump when cheaply encodable,
-- falling back to the node label (e.g. "Array(3)" / "{…}").
local function jnode_value_text(n)
  if not n.container then
    if type(n.text) == "string" and n.text:sub(1, 1) == '"' and n.text:sub(-1) == '"' then
      return n.text:sub(2, -2) -- strip the display quotes for a clean scalar
    end
    return n.text
  end
  local ok, encoded = pcall(vim.json.encode, n.value)
  if ok and type(encoded) == "string" then
    return encoded
  end
  return n.text
end

local function render_jnode(ctx, n, depth)
  local indent = string.rep("  ", depth)
  local marker = n.container and (n.expanded and OPEN or CLOSED) or "  "
  local namepart = n.key and (n.key .. ": ") or ""
  local hl = n.container and "Identifier" or (type(n.text) == "string" and n.text:sub(1, 1) == '"' and "String" or "Number")
  local kvrec = n.key and { k = n.key, v = jnode_value_text(n) } or nil
  push_d(ctx, indent .. marker .. namepart .. n.text, hl, n, kvrec)
  if n.container and n.expanded then
    for _, c in ipairs(children_of(n)) do
      render_jnode(ctx, c, depth + 1)
    end
  end
end

local function section(ctx, title)
  push_d(ctx, "▾ " .. title, "Title", nil)
end

local function kv(ctx, k, v)
  push_d(ctx, "    " .. k .. ": " .. tostring(v), "Normal", nil, { k = tostring(k), v = tostring(v) })
end

-- get a persistent JSON tree root cached on the request, so expand/collapse
-- state survives re-renders. Returns nil if `raw` isn't JSON.
local function get_json_root(req, key, raw)
  local cached = req[key]
  if cached ~= nil then
    return cached or nil
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == "table" then
    local root = json_node(nil, decoded)
    root.expanded = true
    req[key] = root
    return root
  end
  req[key] = false
  return nil
end

local function header_get(h, name)
  if not h then
    return nil
  end
  name = name:lower()
  for k, v in pairs(h) do
    if k:lower() == name then
      return v
    end
  end
  return nil
end

local function url_decode(s)
  s = (s or ""):gsub("+", " ")
  s = s:gsub("%%(%x%x)", function(hx) return string.char(tonumber(hx, 16)) end)
  return s
end

-- parse application/x-www-form-urlencoded into {{key,value}...}, or nil
local function form_pairs(req, raw)
  local ct = header_get(req.reqHeaders, "content-type") or ""
  local looks_form = raw:match("^[%w%.%_%-%[%]%%]+=") ~= nil
  if not (ct:find("x-www-form-urlencoded", 1, true) or looks_form) then
    return nil
  end
  local out = {}
  for pair in raw:gmatch("[^&]+") do
    local k, v = pair:match("^([^=]*)=?(.*)$")
    out[#out + 1] = { url_decode(k), url_decode(v) }
  end
  return #out > 0 and out or nil
end

local function render_detail()
  local buf = state.detail_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local ctx = { lines = {}, hls = {}, map = {}, kv = {} }
  local req = state.selected and state.by_id[state.selected]
  if not req then
    push_d(ctx, "  (select a request)", "Comment", nil)
  else
    section(ctx, "General")
    kv(ctx, "url", req.url or "")
    kv(ctx, "method", req.method or "")
    kv(ctx, "status", status_str(req) .. (req.statusText and (" " .. req.statusText) or ""))
    kv(ctx, "type", req.restype or "")
    if req.mime then kv(ctx, "mime", req.mime) end
    if req.remoteIP and req.remoteIP ~= "" then kv(ctx, "remoteIP", req.remoteIP) end
    if req.protocol and req.protocol ~= "" then kv(ctx, "protocol", req.protocol) end
    kv(ctx, "size", human_size(req.size))
    kv(ctx, "time", duration_str(req))
    kv(ctx, "started", started_str(req))
    kv(ctx, "cache", req.fromCache and "⚡ from disk cache" or "no")
    if req.failed and req.error then kv(ctx, "error", req.error) end

    local function headers(title, h)
      if h and next(h) then
        section(ctx, title)
        local keys = {}
        for k in pairs(h) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do kv(ctx, k, h[k]) end
      end
    end
    headers("Request Headers", req.reqHeaders)
    headers("Response Headers", req.respHeaders)

    if req.postData and req.postData ~= "" then
      section(ctx, "Request Payload")
      local root = get_json_root(req, "_payload_root", req.postData)
      if root then
        render_jnode(ctx, root, 1)
      else
        local form = form_pairs(req, req.postData)
        if form then
          for _, pair in ipairs(form) do
            push_d(ctx, "    " .. pair[1] .. ": " .. pair[2], "Normal", nil, { k = pair[1], v = pair[2] })
          end
        else
          push_d(ctx, "  " .. req.postData, "Normal", nil)
        end
      end
    end

    section(ctx, "Response")
    if req.body_fetched then
      if req.body_error then
        push_d(ctx, "  (failed to load body: " .. tostring(req.body_error) .. ")", "Comment", nil)
      elseif req.body == "" then
        push_d(ctx, "  (empty)", "Comment", nil)
      elseif req.base64 then
        push_d(ctx, "  (binary, " .. #req.body .. " b64 bytes)", "Comment", nil)
      else
        local root = get_json_root(req, "_resp_root", req.body)
        if root then
          render_jnode(ctx, root, 1)
        else
          for _, l in ipairs(vim.split(req.body, "\n", { plain = true })) do
            push_d(ctx, l, "Normal", nil)
          end
        end
      end
    elseif req.body_requested then
      -- a net_body op is genuinely in flight to the bridge
      push_d(ctx, "  (loading response…)", "Comment", nil)
    elseif req.body_wanted then
      -- explicitly selected while still in flight; net_done will fetch it
      push_d(ctx, "  (awaiting response…)", "Comment", nil)
    else
      -- not requested yet — passive scroll only, press <CR>/gd to load
      push_d(ctx, "  (press <CR> to load response body)", "Comment", nil)
    end
  end

  state.detail_nodes = ctx.map
  state.detail_kv = ctx.kv
  set_lines(buf, ctx.lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, hl in pairs(ctx.hls) do
    if hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #ctx.lines[i], hl_group = hl })
    end
  end
end

-- ── selection + body fetch ─────────────────────────────────────────────────

-- Request the response body from the bridge. `req.body_wanted` is the user's
-- explicit intent (set on <CR>/gd) and is recorded even while the request is
-- still in flight, so net_done can complete the fetch once the body exists.
-- `req.body_requested` means a net_body op is actually in flight to the bridge;
-- it is only set once we genuinely send, so the (loading…) placeholder reflects
-- a real fetch and not merely a pending intent.
local function fetch_body(req)
  req.body_wanted = true
  if req.body_fetched or req.body_requested then
    return
  end
  -- can't fetch the body until the response has finished (or failed); the
  -- intent is remembered above and net_done will retry once done_ts is set.
  if not (req.done_ts or req.failed) then
    return
  end
  req.body_requested = true
  state.reqid = state.reqid + 1
  state.pending_body[state.reqid] = req.requestId
  client.send({ op = "net_body", reqid = state.reqid, requestId = req.requestId })
end

-- Select the request under the cursor (highlight + General/Headers in the
-- detail pane). On passive cursor movement we ONLY select; the response body is
-- fetched lazily, but only on an EXPLICIT select (`<CR>`/`gd`) via with_body.
local function select_row(with_body)
  local row = vim.api.nvim_win_get_cursor(state.list_win or 0)[1]
  local req = state.rows[row]
  if not req then
    return
  end
  if state.selected ~= req.requestId then
    state.selected = req.requestId
    render_detail()
  end
  if with_body then
    fetch_body(req)
    -- repaint so the detail pane reflects the new body state: either the
    -- already-fetched body, the genuine "(loading response…)" placeholder, or
    -- the "(awaiting response…)" note for a request still in flight.
    render_detail()
  end
end

-- expand every container node in the detail tree, so a native `/` search finds
-- text buried inside collapsed JSON. Operates on the selected request's roots.
local function expand_all_detail()
  local req = state.selected and state.by_id[state.selected]
  if not req then
    return
  end
  local function walk(node)
    if node and node.container then
      node.expanded = true
      for _, c in ipairs(children_of(node)) do
        walk(c)
      end
    end
  end
  walk(req._payload_root)
  walk(req._resp_root)
  render_detail()
end

local function detail_toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local node = state.detail_nodes[lnum]
  if node and node.container then
    node.expanded = not node.expanded
    render_detail()
    vim.api.nvim_win_set_cursor(state.detail_win, { math.min(lnum, vim.api.nvim_buf_line_count(state.detail_buf)), 0 })
  end
end

-- ── detail copy (yk/yv/yb) ─────────────────────────────────────────────────

-- the { k=…, v=… } record recorded for the detail line under the cursor, or
-- nil for section headers / blank / placeholder lines. lnum is clamped to the
-- rendered buffer so a stale cursor never indexes past the map.
local function kv_under_cursor()
  local win = state.detail_win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return nil
  end
  local n = vim.api.nvim_buf_line_count(state.detail_buf)
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  lnum = math.max(1, math.min(lnum, n))
  return state.detail_kv[lnum]
end

-- copy `text` to both the system (+) and unnamed (") registers, then notify a
-- short, single-line, truncated confirmation labelled by `what`.
local function copy_detail(text, what)
  text = text or ""
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  local preview = text:gsub("[\r\n]+", " ")
  if #preview > 60 then
    preview = preview:sub(1, 59) .. "…"
  end
  vim.notify("copied " .. what .. ": " .. preview)
end

-- yk/yv/yb: copy the key, value, or "key: value" for the line under the cursor.
-- `which` is "k", "v", or "b". Lines without a kv record notify and no-op.
local function detail_copy(which)
  local rec = kv_under_cursor()
  if not rec then
    vim.notify("no key/value on this line", vim.log.levels.WARN)
    return
  end
  if which == "k" then
    copy_detail(rec.k, "key")
  elseif which == "v" then
    copy_detail(rec.v, "value")
  else
    copy_detail((rec.k or "") .. ": " .. (rec.v or ""), "key: value")
  end
end

-- ── event handlers ─────────────────────────────────────────────────────────

local function add_req(req)
  state.requests[#state.requests + 1] = req
  state.by_id[req.requestId] = req
  local over = #state.requests - state.max
  if over > 0 then
    for _ = 1, over do
      local r = table.remove(state.requests, 1)
      if r then state.by_id[r.requestId] = nil end
    end
  end
end

local function register_handlers()
  if state.registered then
    return
  end
  state.registered = true

  client.on("net_request", function(ev)
    local req = state.by_id[ev.requestId]
    if not req then
      req = { requestId = ev.requestId }
      add_req(req)
    end
    req.url = ev.url
    req.method = ev.method
    req.restype = ev.restype
    req.start = ev.ts
    req.wallTime = ev.wallTime -- Unix epoch seconds; rendered as HH:MM:SS
    req.reqHeaders = ev.headers
    req.postData = ev.postData
    render_list()
  end)

  client.on("net_response", function(ev)
    local req = state.by_id[ev.requestId]
    if not req then
      return
    end
    req.status = ev.status
    req.statusText = ev.statusText
    req.mime = ev.mime
    req.restype = ev.restype or req.restype
    req.respHeaders = ev.headers
    req.remoteIP = ev.remoteIP
    req.protocol = ev.protocol
    req.fromCache = ev.fromCache -- served from disk cache → ⚡ marker
    if ev.url and ev.url ~= "" then req.url = ev.url end
    render_list()
    if state.selected == ev.requestId then render_detail() end
  end)

  client.on("net_done", function(ev)
    local req = state.by_id[ev.requestId]
    if not req then
      return
    end
    req.size = ev.size
    req.done_ts = ev.ts
    render_list()
    -- auto-fetch the body if the user already explicitly asked for it (e.g.
    -- pressed <CR>/gd before the request finished). Passive scroll never sets
    -- body_wanted, so it won't trigger a fetch here. This must run regardless of
    -- the current selection — the user may have scrolled away while waiting.
    if req.body_wanted then
      fetch_body(req)
    end
    if state.selected == ev.requestId then
      render_detail()
    end
  end)

  client.on("net_failed", function(ev)
    local req = state.by_id[ev.requestId]
    if not req then
      return
    end
    req.failed = true
    req.error = ev.error
    req.canceled = ev.canceled
    req.done_ts = ev.ts
    render_list()
    -- honour an explicit body request that was placed while still in flight;
    -- the bridge will reply ok=false and the detail pane resolves to the error.
    if req.body_wanted then
      fetch_body(req)
    end
    if state.selected == ev.requestId then render_detail() end
  end)

  client.on("net_body", function(ev)
    local rid = state.pending_body[ev.reqid]
    state.pending_body[ev.reqid] = nil
    local req = rid and state.by_id[rid]
    if not req then
      return
    end
    req.body_fetched = true
    if ev.ok then
      req.body = ev.body or ""
      req.base64 = ev.base64
    else
      req.body = ""
      req.base64 = false
      req.body_error = ev.error
    end
    if state.selected == rid then render_detail() end
  end)

  -- clear all captured traffic + selection (DevTools "preserve log" OFF). Called
  -- on navigation and on (re)attach so a new tab/page never shows stale traffic.
  local function reset_log()
    state.requests = {}
    state.by_id = {}
    state.selected = nil
    state.rows = {}
    state.pending_body = {}
    render_list()
    render_detail()
  end

  -- (re)attach: a fresh "ready" means we're now bound to a (possibly different)
  -- tab — clear stale traffic so reattach doesn't mix tabs, then re-enable.
  client.on("ready", function()
    reset_log()
    if client.is_running() then
      client.enable("network")
    end
  end)

  -- main-frame navigation: the page reloaded/navigated, so old requests are
  -- stale. Clear the log (preserve-log off) and re-enable the domain.
  client.on("navigated", function()
    reset_log()
    if client.is_running() then
      client.enable("network")
    end
  end)

  -- ack of the blocked-URL pattern list from the Go bridge.
  client.on("net_block", function(ev)
    local n = ev.patterns and #ev.patterns or 0
    if ev.ok then
      vim.notify("webnetwork: blocking " .. n .. " URL pattern" .. (n == 1 and "" or "s"))
    else
      vim.notify("webnetwork: net_block failed", vim.log.levels.WARN)
    end
    render_list() -- refresh winbar blocked-count
  end)
end

-- send the current blocked-pattern set to the bridge.
local function send_blocks()
  local pats = {}
  for p in pairs(state.blocked) do
    pats[#pats + 1] = p
  end
  client.send({ op = "net_block", patterns = pats })
end

-- ── copy-as-curl / HAR export ──────────────────────────────────────────────

-- single-quote a string for a POSIX shell (curl command building).
local function shq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- build a `curl` command line reproducing the selected request.
local function build_curl(req)
  local parts = { "curl" }
  local method = (req.method or "GET"):upper()
  if method ~= "GET" then
    parts[#parts + 1] = "-X " .. method
  end
  parts[#parts + 1] = shq(req.url or "")
  if req.reqHeaders then
    local keys = {}
    for k in pairs(req.reqHeaders) do
      keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      parts[#parts + 1] = "-H " .. shq(k .. ": " .. req.reqHeaders[k])
    end
  end
  if req.postData and req.postData ~= "" then
    parts[#parts + 1] = "--data-raw " .. shq(req.postData)
  end
  return table.concat(parts, " \\\n  ")
end

-- convert a header map {name=value,...} to HAR's [{name,value},...].
local function har_headers(h)
  local out = {}
  if h then
    local keys = {}
    for k in pairs(h) do
      keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      out[#out + 1] = { name = k, value = tostring(h[k]) }
    end
  end
  return out
end

-- serialise the (filtered) request list to a HAR 1.2 structure.
local function build_har()
  local entries = {}
  for _, req in ipairs(state.requests) do
    -- best-effort timings: total wait = (done - start) ms, everything else -1.
    local total = (req.start and req.done_ts) and ((req.done_ts - req.start) * 1000) or -1
    local started = req.wallTime and req.wallTime > 0
      and os.date("!%Y-%m-%dT%H:%M:%S.000Z", math.floor(req.wallTime)) or nil

    local post = nil
    if req.postData and req.postData ~= "" then
      post = {
        mimeType = header_get(req.reqHeaders, "content-type") or "application/octet-stream",
        text = req.postData,
      }
    end

    entries[#entries + 1] = {
      startedDateTime = started or "1970-01-01T00:00:00.000Z",
      time = total >= 0 and total or 0,
      request = {
        method = req.method or "GET",
        url = req.url or "",
        httpVersion = req.protocol or "HTTP/1.1",
        headers = har_headers(req.reqHeaders),
        queryString = {},
        cookies = {},
        headersSize = -1,
        bodySize = req.postData and #req.postData or 0,
        postData = post,
      },
      response = {
        status = req.status or 0,
        statusText = req.statusText or "",
        httpVersion = req.protocol or "HTTP/1.1",
        headers = har_headers(req.respHeaders),
        cookies = {},
        content = {
          size = req.size or 0,
          mimeType = req.mime or "",
          text = (req.body_fetched and not req.base64) and req.body or nil,
        },
        redirectURL = "",
        headersSize = -1,
        bodySize = req.size or -1,
        _fromCache = req.fromCache and "disk" or nil,
      },
      cache = vim.empty_dict(),
      timings = {
        send = -1,
        wait = total >= 0 and total or -1,
        receive = -1,
        blocked = -1,
        dns = -1,
        connect = -1,
        ssl = -1,
      },
    }
  end
  return {
    log = {
      version = "1.2",
      creator = { name = "webnetwork.nvim", version = "1.0" },
      pages = {},
      entries = entries,
    },
  }
end

local function export_har()
  local default = vim.fn.stdpath("state") .. "/webconnect-" .. os.date("%Y%m%d-%H%M%S") .. ".har"
  vim.ui.input({ prompt = "HAR export path: ", default = default, completion = "file" }, function(path)
    if path == nil or path == "" then
      return
    end
    local ok, encoded = pcall(vim.json.encode, build_har())
    if not ok then
      vim.notify("webnetwork: HAR encode failed: " .. tostring(encoded), vim.log.levels.ERROR)
      return
    end
    local fd, err = io.open(vim.fn.expand(path), "w")
    if not fd then
      vim.notify("webnetwork: cannot write HAR: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    fd:write(encoded)
    fd:close()
    vim.notify("webnetwork: HAR written to " .. path)
  end)
end

-- ── help float ─────────────────────────────────────────────────────────────

local HELP_LINES = {
  "  webnetwork — Network panel keys",
  "",
  "  List buffer:",
  "    /        filter by URL substring",
  "    1-9 0    toggle resource-type filter (1 = All)",
  "    F        cycle status filter (All → Errors → 4xx → 5xx)",
  "    <CR>     select request + fetch response body",
  "    gd       jump to detail pane (also fetches body)",
  "    yy       yank request URL",
  "    yc       yank request as a curl command",
  "    yr       yank response body",
  "    yp       yank request payload (postData)",
  "    b        block selected request's URL",
  "    B        clear all URL blocks",
  "    H        export request list to HAR",
  "    E        expand all JSON nodes in detail",
  "    X        clear captured requests",
  "    q        close panel",
  "    ?        this help",
  "",
  "  Detail buffer:",
  "    <CR>/<Tab>  expand/collapse JSON node",
  "    E           expand all JSON nodes",
  "    yk          copy key/name under cursor",
  "    yv          copy value under cursor",
  "    yb          copy both as `key: value`",
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
    title = " Network help ",
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

-- ── windows ─────────────────────────────────────────────────────────────

local function setup_list_keys(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  -- explicit select: highlight + fetch the response body
  map("<CR>", function() select_row(true) end, "Select request (+fetch body)")
  map("/", function()
    vim.ui.input({ prompt = "URL filter: ", default = state.filter.url }, function(v)
      if v ~= nil then
        state.filter.url = v
        render_list()
      end
    end)
  end, "Filter by URL")
  -- number keys toggle type filters (1 = All); hjkl stay free for navigation
  map("1", function()
    state.filter.types = {}
    render_list()
  end, "Filter: All")
  for _, b in ipairs(BUTTONS) do
    map(b.num, function()
      state.filter.types[b.label] = not state.filter.types[b.label] or nil
      render_list()
    end, "Toggle " .. b.label)
  end
  -- F cycles the status-class filter: All → Errors → 4xx → 5xx → All
  map("F", function()
    state.filter.status = (state.filter.status % #STATUS_FILTERS) + 1
    render_list()
  end, "Cycle status filter")
  map("X", function()
    state.requests = {}
    state.by_id = {}
    state.selected = nil
    state.rows = {}
    render_list()
    render_detail()
  end, "Clear requests")

  local function row_req()
    return state.rows[vim.api.nvim_win_get_cursor(0)[1]]
  end

  map("yy", function()
    local req = row_req()
    if req and req.url then
      vim.fn.setreg("+", req.url)
      vim.notify("yanked URL: " .. req.url)
    end
  end, "Yank URL")
  map("yc", function()
    local req = row_req()
    if not req then
      return
    end
    local curl = build_curl(req)
    vim.fn.setreg("+", curl)
    vim.notify("yanked curl command (" .. (req.method or "GET") .. " " .. (req.url or "") .. ")")
  end, "Yank as curl")
  map("yr", function()
    local req = row_req()
    if not req then
      return
    end
    if not req.body_fetched then
      vim.notify("webnetwork: body not fetched yet — press <CR> first", vim.log.levels.WARN)
      return
    end
    vim.fn.setreg("+", req.body or "")
    vim.notify("yanked response body (" .. #(req.body or "") .. " bytes)")
  end, "Yank response body")
  map("yp", function()
    local req = row_req()
    if not req then
      return
    end
    if not (req.postData and req.postData ~= "") then
      vim.notify("webnetwork: no request payload", vim.log.levels.WARN)
      return
    end
    vim.fn.setreg("+", req.postData)
    vim.notify("yanked request payload (" .. #req.postData .. " bytes)")
  end, "Yank request payload")
  map("b", function()
    local req = row_req()
    if not (req and req.url and req.url ~= "") then
      return
    end
    state.blocked[req.url] = true
    send_blocks()
    render_list()
  end, "Block request URL")
  map("B", function()
    if next(state.blocked) == nil then
      vim.notify("webnetwork: no blocks to clear")
      return
    end
    state.blocked = {}
    send_blocks()
    render_list()
  end, "Clear all blocks")
  map("H", export_har, "Export HAR")
  map("E", expand_all_detail, "Expand all detail nodes")
  map("gd", function()
    select_row(true) -- explicit select fetches the body before jumping
    if state.detail_win and vim.api.nvim_win_is_valid(state.detail_win) then
      vim.api.nvim_set_current_win(state.detail_win)
    end
  end, "Go to detail (+fetch body)")
  map("?", show_help, "Help")
  map("q", M.close, "Close network panel")
end

local function ensure_bufs()
  if not (state.list_buf and vim.api.nvim_buf_is_valid(state.list_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeNetwork")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webnetwork"
    vim.bo[buf].modifiable = false
    setup_list_keys(buf)
    -- passive cursor movement only SELECTS (highlight + General/Headers); it
    -- never fetches the response body. Body fetch is explicit (<CR>/gd).
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = buf,
      callback = function()
        if vim.api.nvim_get_current_win() == state.list_win then
          select_row(false)
        end
      end,
    })
    state.list_buf = buf
  end
  if not (state.detail_buf and vim.api.nvim_buf_is_valid(state.detail_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeNetworkDetail")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webnetworkdetail"
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "<CR>", detail_toggle, { buffer = buf, desc = "Toggle node" })
    vim.keymap.set("n", "<Tab>", detail_toggle, { buffer = buf, desc = "Toggle node" })
    vim.keymap.set("n", "E", expand_all_detail, { buffer = buf, desc = "Expand all nodes" })
    vim.keymap.set("n", "yk", function() detail_copy("k") end, { buffer = buf, desc = "Copy key" })
    vim.keymap.set("n", "yv", function() detail_copy("v") end, { buffer = buf, desc = "Copy value" })
    vim.keymap.set("n", "yb", function() detail_copy("b") end, { buffer = buf, desc = "Copy key: value" })
    vim.keymap.set("n", "q", M.close, { buffer = buf, desc = "Close" })
    state.detail_buf = buf
  end
end

-- open fullscreen in a dedicated tab (master left / detail right). Buffers
-- and state persist across close, so toggling is cheap and lossless.
function M.open()
  ensure_bufs()
  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
    vim.api.nvim_set_current_win(state.list_win)
    return
  end
  vim.cmd("tabnew")
  state.list_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.list_win, state.list_buf)
  vim.wo[state.list_win].number = false
  vim.wo[state.list_win].relativenumber = false
  vim.wo[state.list_win].wrap = false
  vim.wo[state.list_win].cursorline = true

  vim.cmd("rightbelow vsplit")
  state.detail_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.detail_win, state.detail_buf)
  vim.wo[state.detail_win].number = false
  vim.wo[state.detail_win].relativenumber = false
  vim.wo[state.detail_win].wrap = true
  vim.wo[state.detail_win].winbar = "  Detail  (<CR>/<Tab> expand · E expand-all · yk/yv/yb copy key/value/both)"

  render_list()
  render_detail()
  vim.api.nvim_set_current_win(state.list_win)
end

-- close both windows (tab collapses); buffers + state are kept.
function M.close()
  for _, w in ipairs({ state.detail_win, state.list_win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  state.list_win, state.detail_win = nil, nil
end

function M.toggle()
  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
    M.close()
  else
    M.start()
  end
end

-- ── public API ──────────────────────────────────────────────────────────

function M.start()
  register_handlers()
  M.open()
  client.ensure(function()
    client.enable("network")
  end)
end

function M.stop()
  M.close()
end

return M
