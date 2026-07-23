-- Cross-service navigation for the freelancer-dev/api monorepo.
--
-- Services talk thrift: rest -> midlayer -> dao calls go through
-- libgafthrift's DummyWrapper (__getattr__ dynamic dispatch) or generated
-- Client stubs, so plain LSP definition dead-ends in gaf_thrift-stubs/*.pyi
-- or dummy_wrapper.py and never reaches the handler that implements the
-- method. Names save us: every handler implements the generated Iface with
-- the exact thrift method name, so an exact-name `def` in a real .py file IS
-- the implementation.
--
-- Buffer-local `gd` (api-repo python buffers only, same idiom as the Angular
-- template gd in lua/angular/):
--   gd on a call site  -> LSP definition; if every target is a stub/.pyi or
--                         DummyWrapper, resolve by workspace-symbol name
--                         lookup instead: handler `def`s ranked midlayer >
--                         dao > rest > tests. One hit jumps, many pick.
--   gd on your own def -> the other direction: every `.name(` call site
--                         across all services in a grep picker.
local M = {}

local API_ROOT = vim.fn.expand("~/freelancer-dev/api")

-- Where a plain LSP definition stops being useful. All three proxies
-- dispatch through __getattr__, so LSP definition lands on the proxy class,
-- never the handler.
local DEAD_END_FILES = {
  "dummy_wrapper%.py$",
  "libgafthrift/__init__%.py$", -- class thrift_wrapper
  "gRPC/grpc_wrapper%.py$",
}

local function is_dead_end(uri)
  local path = vim.uri_to_fname(uri)
  if path:sub(-4) == ".pyi" then return true end
  for _, pat in ipairs(DEAD_END_FILES) do
    if path:find(pat) then return true end
  end
  return false
end

-- On an Unknown-typed chain (everything reached through untyped flask
-- `current_app`), pyright "resolves" a definition to whatever it can anchor
-- nearby -- e.g. the enclosing call's function for a kwarg. Only trust a
-- target whose line actually names the word.
local function target_names_word(loc, word)
  local path = vim.uri_to_fname(loc.uri)
  local lnum = loc.range.start.line + 1
  local i = 0
  for line in io.lines(path) do
    i = i + 1
    if i == lnum then
      return line:find(word, 1, true) ~= nil
    end
  end
  return false
end

-- The call site names its target service: `conns.projects_dao.foo(...)` /
-- `conns.users_mid.foo(...)`. Grab the attribute one hop before the cursor
-- word as a soft ranking hint (attr names like projects_dao/users_mid/users
-- are substrings of their service dir).
local function service_hint()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return line:sub(1, col):match("%.([%w_]+)%.[%w_]*$")
end

-- Handlers first: the midlayer/dao class implementing the Iface is almost
-- always the jump the user wants; test doubles come last. A service-name
-- match from the call site outranks everything within its tier.
local function rank(path, hint)
  local r
  if path:find("/tests/") or path:find("/test_") then r = 4
  elseif path:find("_mid/") then r = 1
  elseif path:find("_dao/") then r = 2
  else r = 3 end
  if hint and path:find(hint, 1, true) then r = r - 0.5 end
  return r
end

local function on_own_def_line(word)
  local line = vim.api.nvim_get_current_line()
  return line:match("^%s*def%s+" .. vim.pesc(word) .. "%s*%(") ~= nil
    or line:match("^%s*async%s+def%s+" .. vim.pesc(word) .. "%s*%(") ~= nil
end

-- Reverse direction: all `.word(` call sites across every service. Attribute
-- form only -- bare `word(` locals are already handled by plain LSP.
local function show_callers(word)
  Snacks.picker.grep({
    title = "Callers of " .. word,
    search = "\\." .. word .. "\\(",
    live = false,
    dirs = { API_ROOT },
  })
end

-- vim.schedule + redraw: an async LSP callback can move the cursor without
-- triggering a redraw cycle, leaving the old buffer on screen until the next
-- keystroke (the "have to press j to render" bug). Plain edit + cursor, no
-- show_document: avoids the LSP offset-encoding machinery entirely.
local function jump(file, pos)
  vim.schedule(function()
    vim.cmd.edit(vim.fn.fnameescape(file))
    pcall(vim.api.nvim_win_set_cursor, 0, { pos[1], pos[2] })
    vim.cmd("normal! zz")
    vim.cmd("redraw")
  end)
end

-- Name-based resolution via workspace symbols: exact-name function/method
-- defs in real .py files under the api repo.
local function find_impls(word, client, dead_ends, hint)
  client:request("workspace/symbol", { query = word }, function(err, res)
    local items = {}
    for _, s in ipairs((not err and res) or {}) do
      -- 6 = Method, 12 = Function
      if s.name == word and (s.kind == 6 or s.kind == 12) then
        local path = vim.uri_to_fname(s.location.uri)
        if path:sub(-3) == ".py" and vim.startswith(path, API_ROOT) then
          items[#items + 1] = {
            -- Plain file items only: snacks interprets an `item.loc` as an
            -- LSP location and then requires `item.encoding` -- passing raw
            -- LSP fields froze the picker with "invalid encoding" errors.
            text = path .. " " .. word,
            file = path,
            pos = { s.location.range.start.line + 1, s.location.range.start.character },
            rank = rank(path, hint),
          }
        end
      end
    end
    table.sort(items, function(a, b) return a.rank < b.rank end)
    if #items == 0 then
      -- Nothing real found; a stub def beats staying put.
      if dead_ends[1] then
        jump(vim.uri_to_fname(dead_ends[1].uri),
          { dead_ends[1].range.start.line + 1, dead_ends[1].range.start.character })
      else
        vim.notify("No implementation found for " .. word, vim.log.levels.WARN)
      end
    elseif #items == 1 or items[1].rank < (items[2] and items[2].rank or 5) then
      -- Single hit, or a unique best-ranked hit (the handler): jump straight.
      jump(items[1].file, items[1].pos)
    else
      vim.schedule(function()
        Snacks.picker({
          title = "Implementations of " .. word,
          items = items,
          format = "file",
        })
      end)
    end
  end, 0)
end

-- `conns.gaf.method(...)` is served by the PHP monolith, not a python
-- service: handlers live in fl-gaf src2/Traits/GafThrift/Thrift*Trait.php as
-- `public function <method>(`. Opens in a horizontal split so the python
-- call site stays visible. Zero hits falls back to the normal LSP flow.
local function goto_gaf_php(word, fallback)
  local gaf_root = require("gaf.paths").fl_gaf
  local dirs = {}
  for _, d in ipairs({ gaf_root .. "/src2", gaf_root .. "/src" }) do
    if vim.fn.isdirectory(d) == 1 then dirs[#dirs + 1] = d end
  end
  local cmd = { "rg", "-n", "--no-heading", "-g", "!vendor",
    "function\\s+" .. word .. "\\s*\\(" }
  vim.list_extend(cmd, dirs)
  vim.system(cmd, { text = true }, function(out)
    vim.schedule(function()
      local hits = {}
      for line in (out.stdout or ""):gmatch("[^\n]+") do
        local path, lnum, text = line:match("^(.-):(%d+):(.*)$")
        if path then
          hits[#hits + 1] = { file = path, lnum = tonumber(lnum), text = text }
        end
      end
      local function split_jump(file, lnum)
        vim.cmd("split")
        vim.cmd.edit(vim.fn.fnameescape(file))
        pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
        vim.cmd("normal! zz")
        vim.cmd("redraw")
      end
      if #hits == 0 then
        fallback()
      elseif #hits == 1 then
        split_jump(hits[1].file, hits[1].lnum)
      else
        Snacks.picker({
          title = "GAF implementations of " .. word,
          items = vim.tbl_map(function(h)
            return { text = h.file .. " " .. h.text, file = h.file, pos = { h.lnum, 0 } }
          end, hits),
          format = "file",
          confirm = function(picker, item)
            picker:close()
            split_jump(item.file, item.pos[1])
          end,
        })
      end
    end)
  end)
end

function M.goto_definition()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    Snacks.picker.lsp_definitions()
    return
  end
  if on_own_def_line(word) then
    show_callers(word)
    return
  end
  local client = vim.lsp.get_clients({ bufnr = 0, name = "basedpyright" })[1]
  if not client then
    Snacks.picker.lsp_definitions()
    return
  end
  local hint = service_hint()
  if hint == "gaf" then
    goto_gaf_php(word, function() M.lsp_flow(word, client, nil) end)
    return
  end
  M.lsp_flow(word, client, hint)
end

-- The plain cross-python-service resolution: LSP definition, then
-- name-based workspace-symbol fallback.
function M.lsp_flow(word, client, hint)
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request("textDocument/definition", params, function(err, res)
    res = (not err and res) or {}
    if not vim.islist(res) then res = { res } end
    local dead_ends = {}
    for _, loc in ipairs(res) do
      local uri = loc.uri or loc.targetUri
      if uri then
        local norm = { uri = uri, range = loc.range or loc.targetSelectionRange }
        if not is_dead_end(uri) and target_names_word(norm, word) then
          -- A trustworthy real definition exists; keep the native picker UX.
          vim.schedule(function() Snacks.picker.lsp_definitions() end)
          return
        end
        dead_ends[#dead_ends + 1] = norm
      end
    end
    find_impls(word, client, dead_ends, hint)
  end, 0)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("gaf_python_nav", { clear = true }),
    pattern = "python",
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if not vim.startswith(name, API_ROOT) then return end
      vim.keymap.set("n", "gd", M.goto_definition,
        { buffer = ev.buf, desc = "Go to definition (api cross-service aware)" })
    end,
  })
end

return M
