-- Writing inline review comments from the buffer, the mirror of fetch/render.
--
-- Drafts live here, in the editor, not on the server. Conduit offers no way to
-- edit or delete an inline comment once it exists -- `conduit.query` lists
-- differential.createinline and nothing else for inlines -- so a draft pushed
-- early could only be fixed in the web UI. Instead `:PhabComment` keeps the
-- draft local, where it can be re-opened, rewritten or thrown away, and
-- `:PhabSubmit` is the first call that touches Phabricator:
--
--   1. differential.createinline    per draft, in order
--   2. differential.createcomment   with attach_inlines, which publishes them
--
-- Nothing is visible to the reviewers until step 2.
--
-- Line numbers are the dangerous part: Phabricator stores the line of the
-- *diff's* new-file side, while we hand it a line of the local buffer. Those
-- agree only while the checkout still matches the diff, so a line is verified
-- when the draft is written and again before it is published: the file must be
-- clean against HEAD, the line must fall inside a hunk of the diff, and the
-- text on it must be identical to the diff's. Anything else refuses rather
-- than commenting on the wrong code.

local config   = require("gaf.phab.config")
local revision = require("gaf.phab.revision")
local util     = require("gaf.phab.util")

local M = {}

-- diffs[rev]  = { id = <diffID>, rev_id = <numeric revision id>,
--                 lines = { [path] = { [new_line] = "<text>" } } }
-- drafts[rev] = { { id =, path =, line =, length =, content = }, ... }
local diffs    = {}
local drafts   = {}
local inflight = {}
local next_id  = 0

local ns = vim.api.nvim_create_namespace("gaf_phab_draft")

M.ns = ns

-- ── conduit ────────────────────────────────────────────────────────────────

-- One conduit.sh call. cb(result) on success, cb(nil, err) otherwise. Always
-- called on the main loop, so callers can touch the editor.
local function conduit(method, params, cb)
  vim.system(
    { config.script_path("conduit.sh"), method, vim.json.encode(params) },
    { text = true },
    function(o)
      local err, result
      if o.code ~= 0 then
        err = (o.stderr or ""):gsub("%s+$", "")
      else
        local ok, decoded = pcall(vim.json.decode, o.stdout or "")
        if ok then
          result = decoded
        else
          err = "bad JSON from " .. method
        end
      end
      vim.schedule(function() cb(result, err) end)
    end
  )
end

-- ── raw diff ───────────────────────────────────────────────────────────────

-- Parse a unified diff into { [path] = { [new_line] = "<text>" } }, covering
-- the lines the diff actually shows on its new side (context and additions).
-- Those are exactly the lines Phabricator will accept an inline comment on.
-- Exported so it can be exercised without touching the network.
function M.parse_diff(raw)
  local files, path, new_line = {}, nil, nil

  for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
    local plus = line:match("^%+%+%+ (.+)$")
    if line:match("^%-%-%- ") then
      -- old side; only tells us a file header is being read
      new_line = nil
    elseif plus then
      local p = plus:gsub("\t.*$", ""):gsub("^b/", "")
      path = (p ~= "/dev/null") and p or nil
      new_line = nil
      if path then files[path] = files[path] or {} end
    elseif line:match("^@@") then
      local start = line:match("^@@%s+%-%S+%s+%+(%d+)")
      new_line = tonumber(start)
    elseif new_line and path then
      local kind, text = line:sub(1, 1), line:sub(2)
      if kind == " " or kind == "+" then
        files[path][new_line] = text
        new_line = new_line + 1
      elseif kind == "-" then
        -- old side only: does not advance the new-file counter
      elseif line == "" then
        -- an empty context line arrives without its leading space
        files[path][new_line] = ""
        new_line = new_line + 1
      else
        -- "\ No newline at end of file", or the next file's header
        new_line = nil
      end
    end
  end

  return files
end

-- Resolve rev -> newest diff id + its line map, cached per session. Refetch
-- with `force` after the revision has been updated.
local function load_diff(rev, force, cb)
  if diffs[rev] and not force then
    cb(diffs[rev])
    return
  end
  if inflight[rev] then return end

  local rev_id = tonumber(rev:match("^D(%d+)$"))
  if not rev_id then
    util.notify("cannot parse revision id from " .. rev, vim.log.levels.ERROR)
    return
  end

  inflight[rev] = true
  local progress = util.progress(rev, "diff")

  local function fail(msg)
    inflight[rev] = nil
    progress.fail("diff lookup failed")
    util.notify(msg, vim.log.levels.WARN)
  end

  conduit("differential.revision.search", { constraints = { ids = { rev_id } } }, function(res, err)
    if err then return fail("revision lookup failed for " .. rev .. ": " .. err) end
    local fields = res and res.data and res.data[1] and res.data[1].fields
    local diff_phid = fields and fields.diffPHID
    if not diff_phid then return fail("no diff on " .. rev) end

    conduit("differential.diff.search", { constraints = { phids = { diff_phid } } }, function(dres, derr)
      if derr then return fail("diff lookup failed for " .. rev .. ": " .. derr) end
      local diff_id = dres and dres.data and dres.data[1] and dres.data[1].id
      if not diff_id then return fail("no diff id on " .. rev) end

      conduit("differential.getrawdiff", { diffID = tostring(diff_id) }, function(raw, rerr)
        inflight[rev] = nil
        if rerr or type(raw) ~= "string" then
          return fail("raw diff failed for " .. rev .. ": " .. (rerr or "not a patch"))
        end
        diffs[rev] = { id = diff_id, rev_id = rev_id, lines = M.parse_diff(raw) }
        progress.finish("diff " .. diff_id)
        cb(diffs[rev])
      end)
    end)
  end)
end

-- ── guards ─────────────────────────────────────────────────────────────────

-- Local modifications move every line below them, so a comment written
-- against a changed checkout lands on the wrong code. Refuse instead.
-- Returns nil when clean, a reason string otherwise.
local function local_changes(root, rel)
  local res = vim.system(
    { "git", "-C", root, "status", "--porcelain", "--untracked-files=all", "--", rel },
    { text = true }
  ):wait(2000)
  if not res or res.code ~= 0 then
    return "cannot ask git about " .. rel
  end
  if (res.stdout or ""):gsub("%s+$", "") ~= "" then
    return rel .. " has local changes — commit or stash them before commenting"
  end
  return nil
end

-- Everything that must hold before a line may carry a comment. Returns nil
-- when the line is safe, a reason string otherwise.
local function verify(info, buf, root, rel, line)
  if vim.bo[buf].modified then
    return "buffer has unsaved changes — write or undo them first"
  end

  local changed = local_changes(root, rel)
  if changed then return changed end

  local map = info.lines[rel]
  if not map then
    -- Usually the revision is the wrong one rather than the file: a patched
    -- stack keeps the branch name of the revision it started from, so a
    -- worktree on arcpatch-D229984 can be showing D229985's code.
    local msg = ("%s is not part of D%d (diff %d)"):format(rel, info.rev_id, info.id)
    local head = revision.from_head(root)
    if head and head ~= ("D" .. info.rev_id) then
      msg = msg .. (" — HEAD belongs to %s, switch with :PhabRevision %s"):format(head, head)
    end
    return msg
  end

  local expected = map[line]
  if expected == nil then
    return ("line %d of %s is outside the diff — Phabricator only shows changed lines and their context")
      :format(line, rel)
  end

  local actual = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
  if actual == nil then
    return ("line %d is past the end of %s"):format(line, rel)
  end
  if actual ~= expected then
    return ("line %d of %s does not match the revision's diff — the checkout has drifted, re-patch it")
      :format(line, rel)
  end

  return nil
end

-- Re-verify a draft against the current checkout, loading the file when no
-- buffer holds it. Returns nil or a reason.
local function verify_draft(rev, root, draft)
  local info = diffs[rev]
  if not info then return "the revision's diff is not loaded — :PhabComment first" end

  local abs = root .. "/" .. draft.path
  local buf = vim.fn.bufnr(abs)
  if buf == -1 or not vim.api.nvim_buf_is_loaded(buf) then
    local changed = local_changes(root, draft.path)
    if changed then return changed end
    buf = vim.fn.bufadd(abs)
    vim.fn.bufload(buf)
  end
  for line = draft.line, draft.line + (draft.length or 0) do
    local why = verify(info, buf, root, draft.path, line)
    if why then return why end
  end
  return nil
end

-- ── draft store ────────────────────────────────────────────────────────────

function M.drafts(rev) return drafts[rev] or {} end

local function find(rev, id)
  for i, d in ipairs(M.drafts(rev)) do
    if d.id == id then return i, d end
  end
  return nil
end

-- Draft decorations live in their own namespace, next to (not instead of) the
-- fetched comments, so an unpublished draft is visibly distinct.
function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local rev, root = revision.detect(buf)
  if not rev or not drafts[rev] then return end
  local rel = root and revision.rel_path(buf, root)
  if not rel then return end

  local count = vim.api.nvim_buf_line_count(buf)
  for _, d in ipairs(drafts[rev]) do
    if d.path == rel and d.line <= count then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, d.line - 1, 0, {
        sign_text = "+>",
        sign_hl_group = "DiagnosticInfo",
        virt_text = { { "  draft: " .. (d.content:match("([^\n]*)") or ""), "DiagnosticVirtualTextInfo" } },
        virt_text_pos = "eol",
        priority = 11,
      })
    end
  end
end

local function render_all(rev)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
      if revision.detect(buf) == rev then M.render(buf) end
    end
  end
end

local function clear_decorations()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

-- ── the compose float ──────────────────────────────────────────────────────

-- Remarkup fence for a code suggestion. "code" posts the replacement on its
-- own, which is what reviewers on this instance already do by hand; "diff"
-- posts it against the original, so the change itself is readable.
-- Phabricator has no structured suggestion field -- differential.createinline
-- takes only `content` -- so either way it is text in the comment body.
function M.suggestion_block(lang, original, replacement, style)
  local out = {}
  if style == "diff" then
    table.insert(out, "```lang=diff")
    for _, l in ipairs(original) do table.insert(out, "-" .. l) end
    for _, l in ipairs(replacement) do table.insert(out, "+" .. l) end
  else
    table.insert(out, "```lang=" .. ((lang and lang ~= "") and lang or "text"))
    vim.list_extend(out, replacement)
  end
  table.insert(out, "```")
  return out
end

-- The lines inside the first fenced block, and everything outside it.
local function split_fence(lines)
  local open_at, close_at
  for i, l in ipairs(lines) do
    if l:match("^```") then
      if not open_at then
        open_at = i
      elseif not close_at then
        close_at = i
      end
    end
  end
  if not open_at or not close_at then return nil, lines end
  local inner, outer = {}, {}
  for i, l in ipairs(lines) do
    if i > open_at and i < close_at then
      table.insert(inner, l)
    elseif i < open_at or i > close_at then
      table.insert(outer, l)
    end
  end
  return inner, outer
end

local function trim_trailing(lines)
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  return lines
end

-- spec says where the comment lands; opts says what the float starts with and
-- what happens on write. The buffer is acwrite, so :w and <C-s> are the same
-- action, and closing the window without writing throws the draft away.
---@param spec table rev, path, line, length, draft_id?
---@param opts { title: string, lines: string[], suggest?: table, insert?: boolean, on_save: fun(content: string, win: table) }
local function compose(spec, opts)
  local bname = ("phab://%s/inline/%s:%d"):format(spec.rev, spec.path, spec.line)

  -- The float is short-lived; a leftover buffer of the same name would make
  -- the rename fail, so it goes first.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == bname then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, bname)
  vim.bo[buf].filetype  = "markdown"
  vim.bo[buf].buftype   = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines or { "" })
  vim.bo[buf].modified  = false

  local cfg = config.get().compose or {}
  -- No save key of our own: the buffer is `acwrite`, so `:w` (and `:wq`, and
  -- `:x`) is the save, which is the one binding nobody has to learn. `:q`
  -- discards -- QuitPre below drops the modified flag so it never complains.
  -- `compose.save` can still bind a key for anyone who wants one.
  local function list(value)
    if value == false or value == nil then return {} end
    return type(value) == "table" and value or { value }
  end
  local save_keys = list(cfg.save)
  local quit_keys = list(cfg.discard ~= nil and cfg.discard or { "q", "<esc>" })

  local win
  -- Keyed by the lhs itself, so binding `q` replaces Snacks' own `q = "close"`
  -- entry instead of adding a second mapping for it, which it warns about.
  local keys = {}
  for _, lhs in ipairs(save_keys) do
    keys[lhs] = { lhs, function() vim.cmd("write") end, mode = "n", desc = "Save" }
  end
  for _, lhs in ipairs(quit_keys) do
    keys[lhs] = { lhs, function() win:close() end, mode = "n", desc = "Discard" }
  end

  local hint = save_keys[1] and ("[%s] or :w save"):format(save_keys[1]) or ":w saves"
  local quit_hint = quit_keys[1] and ("[%s] or :q discard"):format(quit_keys[1]) or ":q discards"

  win = Snacks.win({
    buf    = buf,
    enter  = true,
    border = "rounded",
    title  = " " .. opts.title .. " ",
    footer = (" %s  ·  %s "):format(hint, quit_hint),
    width  = cfg.width or 0.7,
    height = cfg.height or 0.4,
    wo     = { wrap = true, linebreak = true, number = false, signcolumn = "no" },
    keys   = keys,
  })

  -- An unwritten draft is meant to be thrown away, so `:q` should not argue
  -- about unsaved changes.
  vim.api.nvim_create_autocmd({ "QuitPre", "WinClosed" }, {
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.bo[buf].modified = false end
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local lines = trim_trailing(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      if #lines == 0 or table.concat(lines, ""):match("^%s*$") then
        util.notify("nothing to save — the comment is empty", vim.log.levels.WARN)
        return
      end

      local content
      if opts.suggest then
        local inner, outer = split_fence(lines)
        if not inner then
          util.notify("the suggestion block is gone — keep the ``` fence", vim.log.levels.WARN)
          return
        end
        if table.concat(inner, "\n") == table.concat(opts.suggest.original, "\n") then
          util.notify("the suggestion is identical to the code", vim.log.levels.WARN)
          return
        end
        local body = trim_trailing(outer)
        table.insert(body, "")
        vim.list_extend(body, M.suggestion_block(
          opts.suggest.lang, opts.suggest.original, inner, opts.suggest.style
        ))
        content = table.concat(trim_trailing(body), "\n")
      else
        content = table.concat(lines, "\n")
      end

      vim.bo[buf].modified = false
      opts.on_save(content, win)
    end,
  })

  if opts.insert ~= false then vim.cmd("startinsert") end
  return win
end

-- ── creating and editing drafts ────────────────────────────────────────────

local function save_draft(spec, content, win)
  local rev = spec.rev
  drafts[rev] = drafts[rev] or {}

  if spec.draft_id then
    local i = find(rev, spec.draft_id)
    if not i then
      util.notify("that draft is gone", vim.log.levels.WARN)
      return
    end
    drafts[rev][i].content = content
    util.notify(("draft on %s:%d updated"):format(spec.path, spec.line))
  else
    next_id = next_id + 1
    table.insert(drafts[rev], {
      id      = next_id,
      path    = spec.path,
      line    = spec.line,
      length  = spec.length,
      content = content,
    })
    util.notify(("draft on %s:%d — %d pending, :PhabSubmit to publish")
      :format(spec.path, spec.line, #M.drafts(rev)))
  end

  render_all(rev)
  if win then win:close() end
end

-- Resolve the revision, the path and the diff, verify every line of the range,
-- then hand a spec to cb. The gate every entry point goes through.
local function with_target(opts, cb)
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local line1 = opts.line1 or vim.api.nvim_win_get_cursor(0)[1]
  local line2 = opts.line2 or line1
  if line2 < line1 then line1, line2 = line2, line1 end

  revision.resolve({ buf = buf, rev = opts.rev, prompt = true }, function(rev, root)
    local rel = revision.rel_path(buf, root)
    if not rel then
      util.notify("this buffer is outside the worktree of " .. rev, vim.log.levels.WARN)
      return
    end

    load_diff(rev, opts.refresh, function(info)
      -- Every line of the range must be a line of the diff, or the comment
      -- would span code Phabricator does not show at that position.
      for line = line1, line2 do
        local why = verify(info, buf, root, rel, line)
        if why then
          util.notify("cannot comment here: " .. why, vim.log.levels.ERROR)
          return
        end
      end

      cb({
        rev     = rev,
        rev_id  = info.rev_id,
        diff_id = info.id,
        root    = root,
        path    = rel,
        abs     = vim.api.nvim_buf_get_name(buf),
        line    = line1,
        length  = line2 - line1,
      }, buf, line1, line2)
    end)
  end)
end

-- opts.line1 / opts.line2: the range to comment on (a visual selection, or the
-- cursor line twice). opts.rev forces the revision, opts.refresh refetches the
-- diff first.
function M.add(opts)
  opts = opts or {}
  with_target(opts, function(spec)
    compose(spec, {
      title   = ("%s  %s:%d"):format(spec.rev, spec.path, spec.line),
      lines   = { "" },
      on_save = function(content, win) save_draft(spec, content, win) end,
    })
  end)
end

-- Same, with the commented lines prefilled as a code block to rewrite. What is
-- left inside the fence becomes the suggestion.
function M.suggest(opts)
  opts = opts or {}
  with_target(opts, function(spec, buf, line1, line2)
    local original = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
    local lang = vim.bo[buf].filetype or ""
    local style = opts.style or config.get().suggest_style or "code"

    local lines = { "", "" }
    vim.list_extend(lines, M.suggestion_block(lang, original, original, "code"))

    compose(spec, {
      title   = ("%s  suggest %s:%d"):format(spec.rev, spec.path, spec.line),
      lines   = lines,
      suggest = { original = original, lang = lang, style = style },
      on_save = function(content, win) save_draft(spec, content, win) end,
    })
  end)
end

-- Re-open a draft. Editing is possible only because drafts are local: once
-- differential.createinline has run there is no Conduit method to change or
-- remove the comment.
function M.edit_draft(rev, id)
  local _, draft = find(rev, id)
  if not draft then
    util.notify("no such draft", vim.log.levels.WARN)
    return
  end
  local spec = {
    rev      = rev,
    path     = draft.path,
    line     = draft.line,
    length   = draft.length,
    draft_id = draft.id,
  }
  compose(spec, {
    title   = ("%s  edit %s:%d"):format(rev, draft.path, draft.line),
    lines   = vim.split(draft.content, "\n", { plain = true }),
    insert  = false,
    on_save = function(content, win) save_draft(spec, content, win) end,
  })
end

function M.delete_draft(rev, id)
  local i, draft = find(rev, id)
  if not i then
    util.notify("no such draft", vim.log.levels.WARN)
    return
  end
  table.remove(drafts[rev], i)
  if #drafts[rev] == 0 then drafts[rev] = nil end
  render_all(rev)
  util.notify(("discarded the draft on %s:%d"):format(draft.path, draft.line))
end

-- Act on the draft under the cursor: `action` is "edit" or "delete".
function M.at_cursor(action, opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local rev, root = revision.detect(buf)
  if not rev then
    util.notify("no revision for this buffer", vim.log.levels.WARN)
    return
  end
  local rel = root and revision.rel_path(buf, root)
  for _, d in ipairs(M.drafts(rev)) do
    if d.path == rel and d.line == line then
      if action == "delete" then return M.delete_draft(rev, d.id) end
      return M.edit_draft(rev, d.id)
    end
  end
  util.notify("no draft on this line", vim.log.levels.WARN)
end

-- ── publishing ─────────────────────────────────────────────────────────────

-- Push the drafts one at a time, then publish them with a cover comment.
-- differential.createcomment's attach_inlines is what turns the pending
-- inlines into visible comments, so the message goes through that endpoint
-- rather than differential.revision.edit.
-- Who the API token belongs to, so a verification only counts our own
-- transactions. Cached for the session.
local me
local function whoami(cb)
  if me ~= nil then
    cb(me)
    return
  end
  conduit("user.whoami", vim.empty_dict(), function(res)
    me = (res and res.phid) or false
    cb(me)
  end)
end

-- What actually landed on the revision. differential.createcomment reports
-- success for a call that applied nothing at all, so the only trustworthy
-- answer comes from reading the revision back.
-- cb({ inlines = n, comments = n }) or cb(nil) when it could not be read.
local function landed_since(rev, since, cb)
  whoami(function(phid)
    conduit("transaction.search", { objectIdentifier = rev, limit = 100 }, function(res, err)
      if err or not res or not res.data then
        cb(nil)
        return
      end
      local out = { inlines = 0, comments = 0 }
      for _, t in ipairs(res.data) do
        local mine = (not phid) or t.authorPHID == phid
        if mine and (tonumber(t.dateCreated) or 0) >= since then
          if t.type == "inline" then
            out.inlines = out.inlines + 1
          elseif t.type == "comment" then
            out.comments = out.comments + 1
          end
        end
      end
      cb(out)
    end)
  end)
end

local function push(rev, list, index, message, progress, on_done)
  if index > #list then
    local since = os.time() - 120
    local rev_id = tonumber(rev:match("^D(%d+)$"))

    local function stuck(detail)
      progress.fail("nothing published")
      util.notify(
        ("%d inline(s) on %s are still unsubmitted drafts (%s). Open the revision and press Submit — "
          .. "they are waiting there. The local drafts are kept."):format(#list, rev, detail),
        vim.log.levels.ERROR
      )
    end

    local function check(detail, on_stuck)
      landed_since(rev, since, function(got)
        if got == nil then
          progress.finish("published (unverified)")
          util.notify(
            ("published on %s, but the revision could not be read back — check it before closing"):format(rev),
            vim.log.levels.WARN
          )
          on_done()
        elseif got.inlines > 0 then
          progress.finish("published " .. got.inlines)
          on_done(got.inlines)
        elseif got.comments > 0 then
          -- The cover comment landed, the inlines did not follow it: this
          -- instance is not attaching them, and re-posting would only add a
          -- second comment.
          stuck("the cover comment posted but the inlines did not follow it")
        else
          on_stuck(detail)
        end
      end)
    end

    -- Second try when createcomment applied nothing at all: the modern edit
    -- endpoint, which is the path the web UI's Submit button goes through.
    local function via_edit()
      conduit("differential.revision.edit", {
        objectIdentifier = rev,
        transactions     = { { type = "comment", value = message ~= "" and message or "Inline comments." } },
      }, function(_, err)
        if err then
          stuck("differential.revision.edit also failed: " .. err)
          return
        end
        check("", function()
          stuck("neither differential.createcomment nor differential.revision.edit published them")
        end)
      end)
    end

    conduit("differential.createcomment", {
      revision_id    = rev_id,
      message        = message ~= "" and message or nil,
      attach_inlines = true,
    }, function(_, err)
      if err then
        util.notify(
          ("differential.createcomment failed on %s (%s) — trying differential.revision.edit"):format(rev, err),
          vim.log.levels.WARN
        )
        via_edit()
        return
      end
      check("", via_edit)
    end)
    return
  end

  local d = list[index]
  conduit("differential.createinline", {
    revisionID = diffs[rev].rev_id,
    diffID     = diffs[rev].id,
    filePath   = d.path,
    lineNumber = d.line,
    lineLength = d.length,
    isNewFile  = true,
    content    = d.content,
  }, function(_, err)
    if err then
      progress.fail("inline " .. index .. " failed")
      util.notify(
        ("inline %d/%d (%s:%d) failed: %s — %d already pending on %s, finish in the web UI")
          :format(index, #list, d.path, d.line, err, index - 1, rev),
        vim.log.levels.ERROR
      )
      return
    end
    push(rev, list, index + 1, message, progress, on_done)
  end)
end

-- Publish every draft of this revision. The cover message rides along as the
-- transaction's top-level comment; leaving it empty publishes the inlines on
-- their own.
function M.submit(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev, root)
    local list = vim.deepcopy(M.drafts(rev))
    if #list == 0 then
      util.notify("no drafts to publish on " .. rev, vim.log.levels.WARN)
      return
    end

    -- The tree may have moved since the drafts were written.
    for _, d in ipairs(list) do
      local why = verify_draft(rev, root, d)
      if why then
        util.notify("refusing to publish: " .. why, vim.log.levels.ERROR)
        return
      end
    end

    vim.ui.input({
      -- Prefilled, because an empty message is what makes Phabricator apply no
      -- transaction at all and leave the inlines unsubmitted.
      prompt  = ("Publish %d inline comment(s) on %s — cover message: "):format(#list, rev),
      default = "Inline comments.",
    }, function(message)
      -- nil is <Esc>; an empty string is "publish, no cover comment".
      if message == nil then
        util.notify("publish cancelled")
        return
      end
      message = vim.trim(message)

      local progress = util.progress(rev, "publishing " .. #list .. " comment(s)")
      push(rev, list, 1, message, progress, function(count)
        drafts[rev] = nil
        clear_decorations()
        util.notify(("published %d inline comment(s) on %s"):format(count or #list, rev))
        -- They are real comments now; pull them back in as such.
        require("gaf.phab").refresh({ buf = opts.buf, rev = rev })
      end)
    end)
  end)
end

-- Picker over the drafts: <CR> edits one, <C-d> discards it, <C-o> jumps to
-- the line it sits on.
function M.list(opts)
  opts = opts or {}
  revision.resolve({ buf = opts.buf, rev = opts.rev, prompt = true }, function(rev, root)
    local items = {}
    for _, d in ipairs(M.drafts(rev)) do
      items[#items + 1] = {
        text     = ("%s:%d %s"):format(d.path, d.line, d.content:match("([^\n]*)") or ""),
        file     = root .. "/" .. d.path,
        pos      = { d.line, 0 },
        draft_id = d.id,
      }
    end
    if #items == 0 then
      util.notify("no drafts on " .. rev)
      return
    end
    Snacks.picker.pick({
      title   = rev .. " drafts (unpublished)",
      items   = items,
      format  = "file",
      preview = "file",
      layout  = { preset = "ivy" },
      confirm = function(picker, item)
        picker:close()
        if item then M.edit_draft(rev, item.draft_id) end
      end,
      actions = {
        draft_delete = function(picker, item)
          if item then M.delete_draft(rev, item.draft_id) end
          picker:close()
        end,
        draft_goto = function(picker, item)
          picker:close()
          if item then Snacks.picker.actions.jump(picker, item) end
        end,
      },
      win = {
        input = {
          keys = {
            ["<c-d>"] = { "draft_delete", mode = { "n", "i" } },
            ["<c-o>"] = { "draft_goto", mode = { "n", "i" } },
          },
        },
      },
    })
  end)
end

-- Test hooks: drive the guards and the store without a network round trip.
function M._verify(info, buf, root, rel, line) return verify(info, buf, root, rel, line) end
function M._set_diff(rev, info) diffs[rev] = info end
function M._add_draft(rev, draft)
  next_id = next_id + 1
  draft.id = next_id
  drafts[rev] = drafts[rev] or {}
  table.insert(drafts[rev], draft)
  return draft.id
end

-- Test hook: wipe the module-local state.
function M._reset()
  diffs    = {}
  drafts   = {}
  inflight = {}
  next_id  = 0
end

return M
