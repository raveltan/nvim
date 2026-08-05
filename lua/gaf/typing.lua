-- Local inter-service typing patch for ~/freelancer-dev/api.
--
-- The api monolith loses all type information at libgafthrift.thrift_wrapper,
-- whose __getattr__ turns every RPC into functools.partial -> Any. The patch
-- restores real thrift signatures: a stub for libgafthrift (covers midlayer->dao
-- and midlayer->midlayer) plus return annotations on the six rest/ accessors
-- that currently claim to return the test-only DummyWrapper.
--
-- The tracked edits (27 files: accessors, handler signatures, mixin conns
-- declarations) are reverted by `git reset --hard`, hence <leader>lT /
-- :GafTypingApply to put them back, or :GafTypingEnsure to do so only when
-- something is actually missing. Apply and revert prompt first, since they write
-- into a repo you may have uncommitted work in; the bang forms
-- (:GafTypingApply!) skip the prompt. See gaf-typing/apply.py and the api repo's
-- docs/inter-service-typing.md.

local M = {}

local ROOT = vim.fn.stdpath("config") .. "/gaf-typing"
local SCRIPT = ROOT .. "/apply.py"
local API = vim.fn.expand("~/freelancer-dev/api")

local function strip_ansi(s) return (s:gsub("\27%[[%d;]*m", "")) end

-- Run apply.py and report through vim.notify. on_done gets the trimmed stdout.
local function run(args, title, on_done)
  local cmd = { "python3", SCRIPT }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(res)
    local out = vim.trim(strip_ansi((res.stdout or "") .. (res.stderr or "")))
    vim.schedule(function()
      if on_done then return on_done(out, res.code) end
      if out == "" then out = res.code == 0 and "ok" or ("failed (exit " .. res.code .. ")") end
      vim.notify(out, res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR,
        { title = title })
    end)
  end)
end

-- Ask before writing. `body` explains the change, `status` is the live output of
-- --check so the prompt describes the actual current state, not a guess.
local function ask(heading, body, status, confirm_label, on_yes)
  local lines = { heading, "" }
  vim.list_extend(lines, body)
  if status ~= "" then
    vim.list_extend(lines, { "", "Current state:", "" })
    for line in (status .. "\n"):gmatch("([^\n]*)\n") do
      if line ~= "" then table.insert(lines, "  " .. line) end
    end
  end
  local choice = vim.fn.confirm(
    table.concat(lines, "\n"), "&" .. confirm_label .. "\n&Cancel", 2, "Warning")
  if choice == 1 then on_yes() end
end

function M.apply(force)
  local function go() run({}, "GAF typing: apply") end
  if force then return go() end
  run({ "--check" }, nil, function(status)
    ask("GAF inter-service typing patch", {
      "This writes into " .. API .. ":",
      "",
      "  tracked    6 rest/ accessors, 5 handler __init__ signatures,",
      "             16 mixin `conns` declarations",
      "             -- git WILL show these 27 files as modified",
      "  untracked  libgafthrift/libgafthrift/__init__.pyi (hidden via .git/info/exclude)",
      "  untracked  docs/inter-service-typing.md",
      "",
      "...and into the api311 virtualenv (outside the repo, git never sees it):",
      "",
      "  site-packages/werkzeug/local.pyi   (kills ~1800 bogus LocalProxy warnings)",
      "  site-packages/flask/globals.pyi    (types current_app.conns)",
      "",
      "These are local developer-experience changes. Do not commit the tracked",
      "edits -- `git reset --hard` reverts them, then press <leader>lT to reapply.",
      "",
      "Any existing edits to those 27 files will be overwritten.",
    }, status, "Apply", go)
  end)
end

function M.revert(force)
  local function go() run({ "--revert" }, "GAF typing: revert") end
  if force then return go() end
  run({ "--check" }, nil, function(status)
    ask("Revert GAF inter-service typing patch", {
      "This restores the six rest/ accessors to `-> DummyWrapper`, drops the",
      "`Connections` annotations from the 5 handlers and 16 mixins, and DELETES",
      "all three stubs: libgafthrift/libgafthrift/__init__.pyi from " .. API .. ",",
      "plus werkzeug/local.pyi and flask/globals.pyi from the api311 virtualenv.",
      "",
      "Inter-service calls go back to resolving as Any: no completion, no",
      "argument checking, no go-to-definition. rest/api also goes back to",
      "~1800 spurious `list[str]` diagnostics from the werkzeug LocalProxy.",
      "",
      "docs/ and .git/info/exclude are left in place.",
    }, status, "Revert", go)
  end)
end

function M.check() run({ "--check" }, "GAF typing: status") end

-- Install only if something is missing, and stay quiet when it is not. This is
-- the one to call after a `git reset`, or from an autocmd -- unlike apply() it
-- costs nothing and says nothing in the common case where all 31 components are
-- already in place. `force` skips the confirmation prompt.
function M.ensure(force)
  run({ "--check" }, nil, function(_, code)
    if code == 0 then return end
    if force then
      run({}, "GAF typing: reinstalled")
    else
      M.apply(false)
    end
  end)
end

function M.setup()
  if vim.fn.filereadable(SCRIPT) ~= 1 then return end

  local cmd = vim.api.nvim_create_user_command
  cmd("GafTypingApply", function(a) M.apply(a.bang) end,
    { bang = true, desc = "GAF typing: reinstall inter-service typing patch (! skips prompt)" })
  cmd("GafTypingRevert", function(a) M.revert(a.bang) end,
    { bang = true, desc = "GAF typing: undo the patch (! skips prompt)" })
  cmd("GafTypingEnsure", function(a) M.ensure(a.bang) end,
    { bang = true, desc = "GAF typing: install only if missing (! skips prompt)" })
  cmd("GafTypingCheck", function() M.check() end,
    { desc = "GAF typing: report patch status" })

  vim.keymap.set("n", "<leader>lT", function() M.apply(false) end,
    { silent = true, desc = "GAF typing: reapply inter-service typing patch" })
end

return M
