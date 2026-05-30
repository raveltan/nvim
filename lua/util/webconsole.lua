-- webconsole: the console REPL panel. A consumer of util.webclient (which owns
-- the shared Chrome connection). Renders a readonly output log + an editable
-- input line, with lazy object trees.
--
--   ┌───────────────────────────┐
--   │ output (readonly)         │  console stream + eval echoes + expandable trees
--   ├───────────────────────────┤
--   │ JS> input (editable)      │  <CR> evaluates · <C-p>/<C-n> history
--   └───────────────────────────┘

local client = require("util.webclient")

local M = {}

local ui = {
  height = 15,
  input_height = 1,
  max_blocks = 500,
  props_limit = 100, -- paging window for getprops "more" nodes
  timestamps = true, -- prefix console lines with HH:MM:SS
}

local state = {
  out_buf = nil,
  in_buf = nil,
  out_win = nil,
  in_win = nil,
  id = 0,
  reqid = 0,
  complete_reqid = 0, -- latest in-flight `complete` request (stale replies ignored)
  complete_cb = nil, -- callback(names) for the latest in-flight `complete` request
  blocks = {},
  linemap = {},
  pending = {}, -- reqid -> node awaiting children
  history = {},
  hist_idx = nil,
  follow = true,
  registered = false,
  rendering = false, -- guard so our own cursor moves don't toggle follow
}

local ns = vim.api.nvim_create_namespace("webconsole")

local LEVEL_HL = {
  error = "DiagnosticError",
  warning = "DiagnosticWarn",
  info = "DiagnosticInfo",
  debug = "Comment",
  log = "Normal",
}

local OPEN, CLOSED = "▾ ", "▸ "

-- ── tree node model ─────────────────────────────────────────────────────

local function mknode(u)
  return {
    name = u.name,
    text = u.text or "",
    type = u.type,
    subtype = u.subtype,
    objectId = u.objectId,
    expandable = u.expandable == true,
    expanded = false,
    children = nil,
    loading = false,
    start = u.start, -- for synthetic "more" paging nodes
  }
end

local function node_hl(n)
  local t = n.type
  if t == "more" then
    return "Comment"
  elseif n.subtype == "null" or t == "undefined" or t == "accessor" then
    return "Comment"
  elseif t == "string" then
    return "String"
  elseif t == "number" then
    return "Number"
  elseif t == "boolean" then
    return "Boolean"
  elseif t == "function" then
    return "Function"
  else
    return "Identifier"
  end
end

-- ── rendering ─────────────────────────────────────────────────────────────

local function push(ctx, line, hl, node)
  for k, seg in ipairs(vim.split(line, "\n", { plain = true })) do
    ctx.lines[#ctx.lines + 1] = (seg:gsub("\r", ""))
    local i = #ctx.lines
    ctx.hls[i] = hl
    ctx.map[i] = (k == 1) and node or nil
  end
end

local function render_node(ctx, n, depth, lead)
  local indent = string.rep("  ", depth)
  if n.type == "more" then
    -- synthetic paging node: "… (more)"; <CR>/<Tab> fetches the next page
    push(ctx, indent .. (lead or "") .. (n.loading and "  " or "… ") .. "(more)", node_hl(n), n)
    return
  end
  local marker = n.expandable and (n.expanded and OPEN or CLOSED) or "  "
  local namepart = n.name and (n.name .. ": ") or ""
  push(ctx, indent .. (lead or "") .. marker .. namepart .. n.text, node_hl(n), n)
  if n.expandable and n.expanded then
    if n.loading then
      push(ctx, indent .. "    <loading…>", "Comment", nil)
    elseif n.children then
      for _, c in ipairs(n.children) do
        render_node(ctx, c, depth + 1, nil)
      end
    end
  end
end

local function render_block(ctx, b)
  if b.kind == "meta" then
    push(ctx, b.text, b.hl, nil)
  elseif b.kind == "echo" then
    push(ctx, "> " .. b.text, "Comment", nil)
  elseif b.kind == "error" then
    push(ctx, b.text, "DiagnosticError", nil)
  elseif b.kind == "console" then
    local ts = (ui.timestamps and b.ts) and (b.ts .. " ") or ""
    push(ctx, string.format("%s%-7s %s%s", ts, b.level, b.text, b.loc or ""), LEVEL_HL[b.level] or "Normal", nil)
    for _, n in ipairs(b.nodes or {}) do
      render_node(ctx, n, 1, nil)
    end
  elseif b.kind == "result" then
    if b.ok then
      render_node(ctx, b.node, 0, "=> ")
    else
      push(ctx, "!! " .. b.error, "DiagnosticError", nil)
    end
  end
end

local function render_all(opts)
  opts = opts or {}
  local buf = state.out_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local ctx = { lines = {}, hls = {}, map = {} }
  for _, b in ipairs(state.blocks) do
    render_block(ctx, b)
  end
  if #ctx.lines == 0 then
    ctx.lines = { "" }
  end
  state.linemap = ctx.map

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, ctx.lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, hl in pairs(ctx.hls) do
    if hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #ctx.lines[i], hl_group = hl })
    end
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then
    local last = math.max(1, #ctx.lines)
    -- our own cursor moves must not trip the CursorMoved follow toggle.
    state.rendering = true
    if opts.cursor then
      vim.api.nvim_win_set_cursor(state.out_win, { math.min(opts.cursor, last), 0 })
    elseif state.follow then
      vim.api.nvim_win_set_cursor(state.out_win, { last, 0 })
    end
    vim.schedule(function() state.rendering = false end)
  end
end

-- ── winbar / status ────────────────────────────────────────────────────────

local STATUS_BADGE = {
  ready = "[●ready]",
  connecting = "[…connecting]",
  off = "[○off]",
}

local function set_out_winbar()
  if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then
    local badge = STATUS_BADGE[client.status()] or "[○off]"
    vim.wo[state.out_win].winbar = "  Chrome console  " .. badge .. "  (yk/yv/yb copy key/value/both · Y value · ? help)"
  end
end

-- ── help float / yank ──────────────────────────────────────────────────────

local HELP_LINES = {
  " Chrome console — keys",
  "",
  " output window",
  "   <CR> / <Tab>   expand / collapse object node (or load more)",
  "   yk / yv / yb   copy key / value / both (name: value) to + and \"",
  "   Y              copy value under cursor (alias of yv)",
  "   ?              this help",
  "",
  " input window",
  "   <CR>           evaluate expression",
  "   <C-p> / <C-n>  history prev / next",
  "   <C-Space>      JS completion (via blink.cmp)",
  "   ?              this help",
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
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = #HELP_LINES,
    row = math.floor((vim.o.lines - #HELP_LINES) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " webconsole help ",
  })
  vim.wo[win].winfixbuf = true
  for _, key in ipairs({ "q", "<Esc>", "?" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })
  end
end

-- resolve the cursor line in the output window into (key, value):
--   tree node  → key = node.name (or empty), value = node.text (the raw value,
--                no marker/indent/`name:` prefix — same as the old Y)
--   plain line → key = empty, value = the line's text (console/result message,
--                echo, meta, error — whatever is on screen)
-- `node` is returned too (nil for plain lines) so callers can branch.
local function resolve_copy()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local node = state.linemap[lnum]
  if node then
    return node.name or "", node.text or "", node
  end
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  return "", line, nil
end

-- copy `val` to both the system clipboard (+) and the unnamed (") register,
-- with a short truncated confirmation prefixed by `label`.
local function copy_reg(val, label)
  val = val or ""
  vim.fn.setreg("+", val)
  vim.fn.setreg('"', val)
  local preview = val:gsub("\n", " ")
  if #preview > 60 then
    preview = preview:sub(1, 57) .. "…"
  end
  vim.notify(label .. ": " .. preview)
end

-- yk: copy the key/name of the node under the cursor.
local function copy_key()
  local key = resolve_copy()
  if key == "" then
    vim.notify("webconsole: no key on this line", vim.log.levels.WARN)
    return
  end
  copy_reg(key, "yanked key")
end

-- yv (also bound to Y): copy the raw value under the cursor.
local function copy_value()
  local _, val = resolve_copy()
  copy_reg(val, "yanked")
end

-- yb: copy `name: value` when the node has a name, else just the value.
local function copy_both()
  local key, val = resolve_copy()
  if key ~= "" then
    copy_reg(key .. ": " .. val, "yanked")
  else
    copy_reg(val, "yanked")
  end
end

local function add_block(b)
  state.blocks[#state.blocks + 1] = b
  local over = #state.blocks - ui.max_blocks
  for _ = 1, over do
    table.remove(state.blocks, 1)
  end
end

-- ── tree expansion ──────────────────────────────────────────────────────

-- request the first page of a node's children.
local function request_props(node)
  state.reqid = state.reqid + 1
  node.reqid = state.reqid
  node.loading = true
  state.pending[state.reqid] = { node = node }
  client.send({ op = "getprops", reqid = state.reqid, objectId = node.objectId, start = 0, limit = ui.props_limit })
end

-- request the next page of children for `parent`, triggered by a synthetic
-- "more" node. The returned children are appended to the parent (the "more"
-- node itself is replaced by the new page, which may carry its own "more").
local function request_more(more_node, parent)
  if not parent or not parent.objectId then
    return
  end
  state.reqid = state.reqid + 1
  more_node.loading = true
  state.pending[state.reqid] = { node = parent, append = true, more = more_node }
  client.send({ op = "getprops", reqid = state.reqid, objectId = parent.objectId, start = more_node.start or 0, limit = ui.props_limit })
end

local function toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local node = state.linemap[lnum]
  if not node then
    return
  end
  -- synthetic paging node: fetch the next page into the parent.
  if node.type == "more" then
    if not node.loading then
      request_more(node, node.parent)
      render_all({ cursor = lnum })
    end
    return
  end
  if not node.expandable then
    return
  end
  if not node.expanded then
    node.expanded = true
    if node.children == nil and node.objectId and not node.loading then
      request_props(node)
    end
  else
    node.expanded = false
  end
  render_all({ cursor = lnum })
end

-- ── JS autocomplete (DevTools-style) ──────────────────────────────────────

-- split the text before the cursor into (base, prefix) per the contract: take
-- the trailing token matching [%w_%$%.%[%]'"]*, then base = everything up to
-- and INCLUDING the last `.` (identifier removed), prefix = the trailing ident.
-- With no `.`, base = "" and prefix = the whole token.
local function parse_complete(line, col)
  local before = line:sub(1, col) -- col is the 0-based cursor col == byte count before cursor
  local token = before:match("[%w_%$%.%[%]'\"]*$") or ""
  local dot = token:match("()%.[^%.]*$") -- byte index of the last `.`
  if dot then
    return token:sub(1, dot), token:sub(dot + 1)
  end
  return "", token
end

-- async completion API consumed by the blink.cmp source (util.cmp_webconsole).
-- `line` is the current input line, `col0` the 0-based byte column of the cursor,
-- and `cb` a function(names) invoked with the list of completion name strings (or
-- `{}`). No-op (cb({})) when disconnected. The reply lands in the `complete`
-- handler below, which calls and clears `state.complete_cb`.
function M.complete_async(line, col0, cb)
  if client.status() ~= "ready" then
    cb({})
    return
  end
  local base, prefix = parse_complete(line, col0)
  state.complete_reqid = state.complete_reqid + 1
  state.complete_cb = cb
  client.send({ op = "complete", reqid = state.complete_reqid, base = base, prefix = prefix })
end

-- ── event handlers (registered with the client) ───────────────────────────

local function register_handlers()
  if state.registered then
    return
  end
  state.registered = true

  client.on("console", function(ev)
    local loc = ""
    if ev.url and ev.url ~= "" then
      loc = " (" .. vim.fn.fnamemodify(ev.url, ":t") .. ":" .. (ev.line or "?") .. ")"
    end
    local nodes = {}
    for _, u in ipairs(ev.args or {}) do
      nodes[#nodes + 1] = mknode(u)
    end
    add_block({ kind = "console", level = ev.level, text = ev.text or "", loc = loc, nodes = nodes, ts = os.date("%H:%M:%S") })
    render_all()
  end)

  client.on("exception", function(ev)
    add_block({ kind = "error", text = "EXC " .. (ev.text or "") })
    render_all()
  end)

  client.on("result", function(ev)
    if ev.ok then
      add_block({ kind = "result", ok = true, node = mknode(ev.node or { text = "undefined", type = "undefined" }) })
    else
      add_block({ kind = "result", ok = false, error = tostring(ev.error) })
    end
    render_all()
  end)

  client.on("props", function(ev)
    local pend = state.pending[ev.reqid]
    state.pending[ev.reqid] = nil
    if not pend then
      return
    end
    local node = pend.node
    node.loading = false

    if pend.append then
      -- paging: drop the consumed "more" node, append the new page to children.
      if pend.more then
        pend.more.loading = false
        for i = #node.children, 1, -1 do
          if node.children[i] == pend.more then
            table.remove(node.children, i)
            break
          end
        end
      end
    else
      node.children = {}
    end

    if ev.ok then
      for _, u in ipairs(ev.children or {}) do
        local c = mknode(u)
        if c.type == "more" then
          c.parent = node -- so request_more can find the owning object
        end
        node.children[#node.children + 1] = c
      end
    else
      node.children[#node.children + 1] = mknode({ text = "<error: " .. tostring(ev.error) .. ">", type = "accessor" })
    end
    render_all()
  end)

  -- JS completion reply. Hand the items to the blink.cmp source via the stored
  -- callback. Ignore stale replies (a newer request superseded this one).
  client.on("complete", function(ev)
    if ev.reqid ~= state.complete_reqid or not state.complete_cb then
      return -- stale or no waiting consumer
    end
    local cb = state.complete_cb
    state.complete_cb = nil
    cb(ev.ok and ev.items or {})
  end)

  client.on("ready", function(ev)
    add_block({ kind = "meta", text = "── connected: " .. (ev.title or "") .. " [" .. (ev.target or "") .. "] ──", hl = "Comment" })
    set_out_winbar()
    render_all()
  end)
  client.on("closed", function()
    add_block({ kind = "meta", text = "── disconnected ──", hl = "Comment" })
    set_out_winbar()
    render_all()
  end)
  client.on("exit", function(ev)
    add_block({ kind = "meta", text = "── webconnect exited (" .. ev.code .. ") ──", hl = "Comment" })
    set_out_winbar()
    render_all()
  end)
  client.on("error", function(ev)
    add_block({ kind = "error", text = "connector: " .. (ev.text or "") })
    render_all()
  end)
  client.on("stderr", function(ev)
    add_block({ kind = "error", text = "stderr: " .. (ev.text or "") })
    render_all()
  end)

  -- page called console.clear(): wipe our buffer too.
  client.on("clear", function()
    M.clear()
  end)

  -- main-frame navigation / execution-context reset: any retained objectIds are
  -- now stale. Drop a marker and invalidate all expanded object trees so a
  -- re-expand re-fetches against the new context.
  client.on("navigated", function(ev)
    add_block({ kind = "meta", text = "── navigated: " .. (ev.url or "") .. " ──", hl = "Comment" })
    state.pending = {} -- in-flight getprops are bound to dead objectIds
    local function invalidate(nodes)
      for _, n in ipairs(nodes or {}) do
        n.expanded = false
        n.loading = false
        if n.children then
          invalidate(n.children)
          n.children = nil -- force re-fetch on next expand
        end
      end
    end
    for _, b in ipairs(state.blocks) do
      if b.kind == "console" then
        invalidate(b.nodes)
      elseif b.kind == "result" and b.node then
        invalidate({ b.node })
      end
    end
    set_out_winbar()
    render_all()
  end)
end

-- ── windows / buffers ─────────────────────────────────────────────────────

local function submit()
  local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(state.in_buf, 0, -1, false), "\n"))
  if text == "" then
    return
  end
  state.history[#state.history + 1] = text
  state.hist_idx = nil
  vim.api.nvim_buf_set_lines(state.in_buf, 0, -1, false, { "" })
  state.follow = true
  M.eval(text)
  vim.cmd("startinsert")
end

local function history(delta)
  if #state.history == 0 then
    return
  end
  if state.hist_idx == nil then
    state.hist_idx = #state.history + 1
  end
  state.hist_idx = math.max(1, math.min(#state.history + 1, state.hist_idx + delta))
  local val = state.history[state.hist_idx] or ""
  vim.api.nvim_buf_set_lines(state.in_buf, 0, -1, false, { val })
  vim.api.nvim_win_set_cursor(state.in_win, { 1, #val })
end

local function ensure_bufs()
  if not (state.out_buf and vim.api.nvim_buf_is_valid(state.out_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeConsole")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "webconsole"
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "<CR>", toggle, { buffer = buf, desc = "Toggle tree node / load more" })
    vim.keymap.set("n", "<Tab>", toggle, { buffer = buf, desc = "Toggle tree node / load more" })
    vim.keymap.set("n", "yk", copy_key, { buffer = buf, desc = "Copy key/name under cursor" })
    vim.keymap.set("n", "yv", copy_value, { buffer = buf, desc = "Copy value under cursor" })
    vim.keymap.set("n", "yb", copy_both, { buffer = buf, desc = "Copy key: value under cursor" })
    vim.keymap.set("n", "Y", copy_value, { buffer = buf, desc = "Copy value under cursor (alias of yv)" })
    vim.keymap.set("n", "?", show_help, { buffer = buf, desc = "Console help" })
    -- autoscroll-follow toggle: while the user reads scrollback (cursor not on
    -- the last line) stop yanking the cursor to new output; resume when they
    -- return to the bottom. Our own render-time cursor moves are guarded.
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = buf,
      callback = function()
        if state.rendering then
          return
        end
        local win = state.out_win
        if not (win and vim.api.nvim_win_is_valid(win)) then
          return
        end
        local cur = vim.api.nvim_win_get_cursor(win)[1]
        local last = vim.api.nvim_buf_line_count(buf)
        state.follow = (cur >= last)
      end,
    })
    state.out_buf = buf
  end
  if not (state.in_buf and vim.api.nvim_buf_is_valid(state.in_buf)) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "ChromeConsoleInput")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "javascript"
    -- marker so the blink.cmp source (util.cmp_webconsole) recognises this buffer
    -- and stays inert everywhere else. JS completion (incl. `.` and <C-Space>) is
    -- now driven by blink.cmp against M.complete_async.
    vim.b[buf].webconsole_input = true
    vim.keymap.set({ "i", "n" }, "<CR>", submit, { buffer = buf, desc = "Eval input" })
    vim.keymap.set({ "i", "n" }, "<C-p>", function() history(-1) end, { buffer = buf, desc = "Prev history" })
    vim.keymap.set({ "i", "n" }, "<C-n>", function() history(1) end, { buffer = buf, desc = "Next history" })
    vim.keymap.set("n", "?", show_help, { buffer = buf, desc = "Console help" })
    state.in_buf = buf
  end
end

-- open fullscreen in a dedicated tab: output (big) above, input (1 line) below.
-- Buffers + state persist across close, so toggling is lossless.
function M.open()
  ensure_bufs()
  local out_ok = state.out_win and vim.api.nvim_win_is_valid(state.out_win)
  local in_ok = state.in_win and vim.api.nvim_win_is_valid(state.in_win)
  if out_ok and in_ok then
    vim.api.nvim_set_current_win(state.in_win)
    vim.cmd("startinsert")
    return
  end

  vim.cmd("tabnew")
  state.out_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.out_win, state.out_buf)
  vim.wo[state.out_win].number = false
  vim.wo[state.out_win].relativenumber = false
  vim.wo[state.out_win].wrap = true
  vim.wo[state.out_win].linebreak = true
  set_out_winbar()

  vim.cmd("belowright split")
  state.in_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.in_win, state.in_buf)
  vim.api.nvim_win_set_height(state.in_win, ui.input_height)
  vim.wo[state.in_win].number = false
  vim.wo[state.in_win].relativenumber = false
  vim.wo[state.in_win].winfixheight = true
  vim.wo[state.in_win].winbar = "  JS ›  (<CR> eval · <C-p>/<C-n> history · <C-Space> complete via blink)"

  render_all()
  vim.api.nvim_set_current_win(state.in_win)
  vim.cmd("startinsert")
end

M.focus = M.open

-- close both windows (tab collapses); buffers + history are kept.
function M.close()
  vim.cmd("stopinsert")
  for _, w in ipairs({ state.in_win, state.out_win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  state.out_win, state.in_win = nil, nil
end

function M.toggle()
  if (state.out_win and vim.api.nvim_win_is_valid(state.out_win))
    or (state.in_win and vim.api.nvim_win_is_valid(state.in_win)) then
    M.close()
  else
    M.start()
  end
end

-- ── public API ──────────────────────────────────────────────────────────

function M.setup(opts)
  opts = opts or {}
  client.setup(opts)
  for _, k in ipairs({ "height", "input_height", "max_blocks" }) do
    if opts[k] ~= nil then
      ui[k] = opts[k]
    end
  end
end

function M.is_running()
  return client.is_running()
end

function M.start(opts)
  opts = opts or {}
  register_handlers()
  M.open()
  if not client.is_running() then
    client.start()
  end
  if opts.then_eval then
    M.eval(opts.then_eval)
  end
end

function M.launch(opts)
  opts = opts or {}
  register_handlers()
  M.open()
  opts.after = function()
    if not client.is_running() then
      client.start()
    end
  end
  client.launch(opts)
end

function M.stop()
  client.stop()
end

function M.eval(expr)
  if not expr or expr == "" then
    return
  end
  register_handlers()
  if not (state.out_win and vim.api.nvim_buf_is_valid(state.out_buf) and vim.api.nvim_win_is_valid(state.out_win)) then
    M.open()
  end
  client.ensure(function()
    state.id = state.id + 1
    add_block({ kind = "echo", text = expr })
    render_all()
    client.send({ id = state.id, op = "eval", expr = expr })
  end)
end

function M.eval_line()
  M.eval(vim.api.nvim_get_current_line())
end

function M.eval_visual()
  local save = vim.fn.getreg("v")
  vim.cmd('noautocmd normal! "vy')
  local sel = vim.fn.getreg("v")
  vim.fn.setreg("v", save)
  M.eval(sel)
end

function M.eval_prompt()
  vim.ui.input({ prompt = "JS> " }, function(input)
    if input then
      M.eval(input)
    end
  end)
end

-- empty the console and re-render an empty buffer. Best-effort releases any
-- retained objectIds we can cheaply find so Chrome can GC them.
function M.clear()
  local function release(nodes)
    for _, n in ipairs(nodes or {}) do
      if n.objectId then
        client.send({ op = "release", objectId = n.objectId })
      end
      if n.children then
        release(n.children)
      end
    end
  end
  for _, b in ipairs(state.blocks) do
    if b.kind == "console" then
      release(b.nodes)
    elseif b.kind == "result" and b.node then
      release({ b.node })
    end
  end
  state.blocks = {}
  state.linemap = {}
  state.pending = {}
  state.follow = true
  render_all()
end

function M.reload()
  client.reload()
end

function M.navigate(url)
  client.navigate(url)
end

function M.build()
  client.build()
end

return M
