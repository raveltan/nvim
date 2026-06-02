-- tagmatch.nvim
-- Treesitter-based tag matching: jump between open/close tags with `%`, and
-- inner/around tag text objects `i%` / `a%`. Works across every grammar that exposes
-- HTML- or JSX-style element nodes -- html, xml, Angular (incl. inline `template:`
-- strings in .ts), JSX/TSX (React), Vue, Svelte, eruby, php, and anything else whose
-- treesitter tree (native or injected) contains these node types.
--
-- Why treesitter and not matchit/vim-matchup `b:match_words`: matchit matches inside
-- string literals poorly (Angular inline templates), can't follow injected trees, and
-- its html mode matches the angle brackets `<`..`>` rather than the open/close tag
-- pair. The tree knows the real structure, including hyphenated custom elements
-- (`<fl-button>`), nesting, and multi-line tags.
--
-- Outside a tag (or in a buffer with no tag tree at the cursor) every mapping falls
-- back to vim-matchup if present, else the builtin `%` -- so normal bracket matching
-- is untouched.

local M = {}

-- Node types, unioned across the two families. They're globally unique, so a single
-- set per role disambiguates html-family vs jsx-family without dispatching on lang.
local OPEN = { start_tag = true, jsx_opening_element = true }
local CLOSE = { end_tag = true, jsx_closing_element = true }
local SELF = { self_closing_tag = true, jsx_self_closing_element = true }
local ELEMENT = { element = true, jsx_element = true }

local function is_tagish(t)
  return ELEMENT[t] or OPEN[t] or CLOSE[t] or SELF[t]
end

local config = {
  -- Filetypes to attach mappings to. The treesitter check self-gates: in a buffer
  -- with no tag node at the cursor, mappings fall back, so a broad list is safe.
  filetypes = {
    "html", "xml", "xhtml", "htmlangular", "vue", "svelte", "handlebars",
    "htmldjango", "heex", "eruby", "php", "markdown", "javascript",
    "javascriptreact", "jsx", "typescript", "typescriptreact", "tsx", "astro",
  },
  -- Set any to false to skip that mapping.
  mappings = { jump = "%", inner = "i%", around = "a%" },
  -- Per-action fallback keys when the cursor isn't on a tag. nil = auto (vim-matchup
  -- <Plug> if installed, else builtin `%` for jump / nothing for the text objects);
  -- false = no fallback; a string = feed those keys (remapped).
  fallback = { jump = nil, inner = nil, around = nil },
}

-- ── helpers ────────────────────────────────────────────────────────────────────

local function cursor_rc()
  local p = vim.api.nvim_win_get_cursor(0) -- {row (1-based), col (0-based)}
  return p[1] - 1, p[2]
end

local _has_matchup
local function has_matchup()
  if _has_matchup then return true end -- never cache a negative (matchup loads lazily)
  _has_matchup = vim.fn.maparg("<Plug>(matchup-%)", "n") ~= ""
  return _has_matchup
end

local AUTO = {
  jump = function() return has_matchup() and "<Plug>(matchup-%)" or "%" end,
  inner = function() return has_matchup() and "<Plug>(matchup-i%)" or false end,
  around = function() return has_matchup() and "<Plug>(matchup-a%)" or false end,
}

-- Resolved fallback keys for an action ("jump"|"inner"|"around"), or nil for none.
local function fallback(action)
  local v = config.fallback[action]
  if v == nil then v = AUTO[action]() end
  if v == false or v == "" then return nil end
  return v
end

-- Smallest named node at (row, col) that sits within a tag structure, searched across
-- ALL injected trees -- so the html inside eruby/php or the angular inside a `.ts`
-- template string is found even though the outer tree reports only text there.
local function tag_node_at(row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then return nil end
  pcall(parser.parse, parser, true)
  local found
  parser:for_each_tree(function(tree, _ltree)
    local root = tree and tree:root()
    if not (root and vim.treesitter.is_in_node_range(root, row, col)) then return end
    local node = root:named_descendant_for_range(row, col, row, col)
    local probe = node
    while probe do
      if is_tagish(probe:type()) then
        found = node -- innermost tree wins (later iterations are deeper)
        return
      end
      probe = probe:parent()
    end
  end)
  return found
end

local function ancestor(node, pred)
  while node do
    if pred(node:type()) then return node end
    node = node:parent()
  end
end

local function child_tags(element)
  local open, close
  for child in element:iter_children() do
    local t = child:type()
    if OPEN[t] then
      open = child
    elseif CLOSE[t] then
      close = child
    end
  end
  return open, close
end

-- treesitter exclusive end (row, col) -> inclusive (row, col), wrapping a col-0 end to
-- the previous line's last column.
local function excl_to_incl(row, col)
  if col > 0 then return row, col - 1 end
  local prev = row - 1
  local line = vim.api.nvim_buf_get_lines(0, prev, prev + 1, false)[1] or ""
  return prev, math.max(#line - 1, 0)
end

-- Charwise-visual selection [sr,sc]..[er,ec] (0-based rows/cols, ec inclusive). Must
-- not already be in visual mode when `` `<v`> `` runs (there `v` would toggle visual
-- off); operator-pending needs the `v` to start the visual it consumes.
local function select_charwise(sr, sc, er, ec)
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.cmd("normal! \27")
  end
  vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
  vim.api.nvim_buf_set_mark(0, ">", er + 1, ec, {})
  vim.cmd("normal! `<v`>")
end

local function feed(keys, remap)
  if not keys then return end
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, false, true),
    remap and "m" or "n",
    false
  )
end

-- ── public actions ───────────────────────────────────────────────────────────

-- True when an element/self-closing tag encloses the cursor (used to route i%/a%).
function M.has_tag()
  local node = tag_node_at(cursor_rc())
  return node ~= nil and ancestor(node, function(t) return ELEMENT[t] or SELF[t] end) ~= nil
end

-- `%`: toggle between an element's opening and closing tag.
function M.jump()
  local node = tag_node_at(cursor_rc())
  local tag = node and ancestor(node, function(t) return OPEN[t] or CLOSE[t] or SELF[t] end)
  if not tag then
    local k = fallback("jump")
    if k == "%" then
      pcall(vim.cmd, "normal! %") -- builtin, avoids recursing into this mapping
    else
      feed(k, true)
    end
    return
  end
  if SELF[tag:type()] then return end -- nothing to pair with

  local element = ancestor(tag:parent(), function(t) return ELEMENT[t] end)
  if not element then return end
  local open, close = child_tags(element)
  if not (open and close) then return end

  local target = OPEN[tag:type()] and close or open
  local trow, tcol = target:start()
  vim.api.nvim_win_set_cursor(0, { trow + 1, tcol })
end

-- `i%` / `a%` selection (invoked via our <Plug>, so an element is known to enclose
-- the cursor). inner = content between the tags; around = the whole element.
function M.select(inner)
  local node = tag_node_at(cursor_rc())
  local element = node and ancestor(node, function(t) return ELEMENT[t] or SELF[t] end)
  if not element then return end

  if not inner or SELF[element:type()] then
    if inner then return end -- nothing inside a self-closing tag
    local sr, sc, er, ec = element:range()
    er, ec = excl_to_incl(er, ec)
    return select_charwise(sr, sc, er, ec)
  end

  -- Prefer the span of named content children (clean, avoids leaking a multi-line
  -- start tag's trailing `>`); fall back to the byte span between the tags when the
  -- content is non-native (e.g. eruby `<%= %>` leaves no html child node).
  local first, last
  for child in element:iter_children() do
    local t = child:type()
    if child:named() and not (OPEN[t] or CLOSE[t] or SELF[t]) then
      first = first or child
      last = child
    end
  end

  local sr, sc, er, ec
  if first then
    sr, sc = first:start()
    er, ec = excl_to_incl(last:end_())
  else
    local open, close = child_tags(element)
    if not (open and close) then return end
    sr, sc = open:end_()
    er, ec = excl_to_incl(close:start())
    local line = vim.api.nvim_buf_get_lines(0, sr, sr + 1, false)[1] or ""
    if sc > #line then -- start tag's `>` ended its line: content begins next line
      sr, sc = sr + 1, 0
    end
  end
  if sr > er or (sr == er and sc > ec) then return end -- empty element
  select_charwise(sr, sc, er, ec)
end

-- ── setup ────────────────────────────────────────────────────────────────────

local function attach(buf)
  local m, o = config.mappings, { buffer = buf, silent = true }
  if m.jump then
    vim.keymap.set({ "n", "x" }, m.jump, M.jump,
      vim.tbl_extend("force", o, { desc = "tagmatch: jump matching tag" }))
  end
  -- Operator-pending + visual via <expr>: RETURN the keys. Operator-pending can't take
  -- an imperative selection (the operator aborts before async keys run); returning our
  -- <Plug> routes to the imperative handler, and returning matchup's <Plug> runs it
  -- natively. Visual works through the same path.
  if m.inner then
    vim.keymap.set({ "x", "o" }, m.inner, function()
      return M.has_tag() and "<Plug>(TagMatchInner)" or (fallback("inner") or "")
    end, vim.tbl_extend("force", o, { expr = true, remap = true, desc = "tagmatch: inner tag" }))
  end
  if m.around then
    vim.keymap.set({ "x", "o" }, m.around, function()
      return M.has_tag() and "<Plug>(TagMatchAround)" or (fallback("around") or "")
    end, vim.tbl_extend("force", o, { expr = true, remap = true, desc = "tagmatch: around tag" }))
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- <Plug> handlers do the imperative selection (the in-template branch of the <expr>
  -- maps routes here). Global; inert unless invoked.
  vim.keymap.set({ "x", "o" }, "<Plug>(TagMatchInner)", function() M.select(true) end, { silent = true })
  vim.keymap.set({ "x", "o" }, "<Plug>(TagMatchAround)", function() M.select(false) end, { silent = true })

  local want = {}
  for _, ft in ipairs(config.filetypes) do
    want[ft] = true
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tagmatch", { clear = true }),
    pattern = config.filetypes,
    callback = function(args) attach(args.buf) end,
  })

  -- Attach to buffers already open when setup runs (e.g. lazy-loaded after the file).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and want[vim.bo[buf].filetype] then
      attach(buf)
    end
  end
end

return M
