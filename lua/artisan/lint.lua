-- phpstan / larastan integration.
--
-- Guarded three ways before it will ever spawn:
--   1. the buffer must sit under an `artisan` root (so fl-gaf keeps phpcs and
--      never starts a second, much slower analyser)
--   2. the project must ship the binary
--   3. the project must ship a phpstan config — with none, phpstan analyses
--      nothing, exits non-zero and produces no JSON
local laravel = require("artisan")

local M = {}

local CONFIGS = { "phpstan.neon", "phpstan.neon.dist", "phpstan.dist.neon" }

---@param root string
---@return string|nil
local function config_file(root)
  for _, name in ipairs(CONFIGS) do
    local p = root .. "/" .. name
    if vim.uv.fs_stat(p) then return p end
  end
  return nil
end

local broken_include_reported = {}

--- A missing `includes:` target — the usual one being a stale
--- `vendor/larastan/...` path after a composer change — makes phpstan exit 1
--- while writing NOTHING to either stdout or stderr. There is no output to
--- parse and no stream to watch, so the run is indistinguishable from a clean
--- file. Catch it here instead, before spawning a process that cannot succeed.
---@param config string
---@return string|nil missing path
local function missing_include(config)
  local ok, lines = pcall(vim.fn.readfile, config)
  if not ok then return nil end
  local dir = vim.fs.dirname(config)
  local in_includes = false
  for _, line in ipairs(lines) do
    if line:match("^includes:") then
      in_includes = true
    elseif in_includes then
      local entry = line:match("^%s+%-%s*(.+)%s*$")
      if not entry then
        if line:match("^%S") then in_includes = false end
      -- Skip neon parameter expansion (%rootDir%, %currentWorkingDirectory%);
      -- resolving those needs phpstan itself.
      elseif not entry:find("%%") then
        entry = entry:gsub("^['\"]", ""):gsub("['\"]$", "")
        local path = entry:sub(1, 1) == "/" and entry or (dir .. "/" .. entry)
        if not vim.uv.fs_stat(path) then return entry end
      end
    end
  end
  return nil
end

--- Everything phpstan needs, or nil if this buffer/project isn't eligible.
---@param bufnr integer|nil
---@return { bin: string, config: string, root: string }|nil
function M.resolve(bufnr)
  local root = laravel.root(bufnr)
  if not root then return nil end
  local bin = laravel.bin("phpstan", root)
  if not bin then return nil end
  local config = config_file(root)
  if not config then return nil end

  local missing = missing_include(config)
  if missing then
    if not broken_include_reported[config .. missing] then
      broken_include_reported[config .. missing] = true
      vim.notify(
        ("phpstan: %s includes a file that does not exist: %s\nphpstan would exit silently, so it is not being run.")
          :format(vim.fn.fnamemodify(config, ":."), missing),
        vim.log.levels.WARN
      )
    end
    return nil
  end

  return { bin = bin, config = config, root = root }
end

-- Bootstrapping larastan loads the whole framework, so the default 128M dies on
-- any real app. `analyse` (not the `analyze` alias the nvim-lint builtin uses)
-- is phpstan's own spelling.
local BASE_ARGS = { "analyse", "--error-format=json", "--no-progress", "--memory-limit=2G" }

-- PHPStan 2.x sniffs these and switches to an "AI agent" output shape that
-- OVERRIDES --error-format=json (see its AiAgentDetector::ENV_VARS). Neovim
-- launched from an agent-managed terminal therefore inherits the marker and
-- gets zero diagnostics on every save, plus one unparseable-output warning.
-- Strip them for the phpstan process only.
local AI_AGENT_VARS = {
  "AI_AGENT", "AMP_CURRENT_THREAD_ID", "AUGMENT_AGENT", "CLAUDECODE", "CLAUDE_CODE",
  "CLAUDE_CODE_ENTRYPOINT", "CODEX_SANDBOX", "CODEX_THREAD_ID", "CURSOR_AGENT",
  "CURSOR_TRACE_ID", "GEMINI_CLI", "OPENCODE", "OPENCODE_CLIENT", "REPL_ID",
}

--- The current environment minus the agent markers. Returned whole because both
--- consumers replace the child environment rather than merging into it.
---@return table<string, string>
function M.clean_env()
  local env = vim.fn.environ()
  for _, name in ipairs(AI_AGENT_VARS) do
    env[name] = nil
  end
  return env
end

--- phpstan writes diagnostics to stdout but bootstrap failures to stderr, so the
--- linter reads both and the JSON is located inside the combined text. Reading
--- stdout alone made the most common failure (a bad `includes:`, a missing
--- extension) completely silent: empty stdout, parser never called, no warning.
---@param output string
---@return string|nil json, string|nil noise
local function split_output(output)
  local start = output:find('{"totals"', 1, true) or output:find("{", 1, true)
  if not start then return nil, output end
  return output:sub(start), start > 1 and output:sub(1, start - 1) or nil
end

---@param ctx { bin: string, config: string, root: string }
---@return string[]
local function args(ctx)
  local out = vim.list_extend({}, BASE_ARGS)
  vim.list_extend(out, { "-c", ctx.config })
  return out
end

--- Point nvim-lint's phpstan linter at the *buffer's* project instead of cwd.
--- The builtin resolves `vendor/bin/phpstan` with fnamemodify(':p'), i.e.
--- relative to cwd — the exact failure already documented for phpcs in
--- plugins/formatting.lua (spawn error on every save when nvim wasn't started
--- from the project root).
---@param lint table the `lint` module
function M.configure(lint)
  local phpstan = lint.linters.phpstan

  phpstan.cmd = function()
    local ctx = M.resolve(0)
    -- try_lint() is only ever called with "phpstan" when resolve() succeeded
    -- (see M.php_linters), so nil here means the project changed under us.
    return ctx and ctx.bin or "phpstan"
  end

  -- `args` must stay a LIST: nvim-lint does vim.tbl_map over it, so a function
  -- in its place is silently dropped (phpstan then runs with no arguments, emits
  -- non-JSON, and every save reports zero diagnostics). Only the elements may be
  -- functions — nvim-lint evaluates each one with cwd set to the lint cwd.
  phpstan.args = vim.list_extend(vim.list_extend({}, BASE_ARGS), {
    "-c",
    function()
      local ctx = M.resolve(0)
      return ctx and ctx.config or "phpstan.neon"
    end,
  })

  phpstan.env = M.clean_env()
  phpstan.stream = "both"

  -- The builtin parser calls vim.json.decode unguarded. Any non-JSON (a PHP
  -- fatal while bootstrapping the container, a missing larastan extension, a
  -- memory abort) then throws inside the lint callback and repeats on every
  -- save. Report each distinct failure once instead.
  local builtin_parser = phpstan.parser
  local reported = {}
  local function warn_once(msg)
    if reported[msg] then return end
    reported[msg] = true
    vim.notify("phpstan: " .. msg, vim.log.levels.WARN)
  end

  phpstan.parser = function(output, bufnr)
    if output == nil or vim.trim(output) == "" then return {} end
    local json, noise = split_output(output)
    if not json then
      return warn_once(vim.trim(noise):sub(1, 400)) or {}
    end
    local ok, diagnostics = pcall(builtin_parser, json, bufnr)
    if not ok then
      return warn_once("unparseable output\n" .. vim.trim(output):sub(1, 400)) or {}
    end
    return diagnostics
  end
end

--- Linter names to run for a php buffer. Called from the BufWritePost dispatch
--- in plugins/formatting.lua rather than being declared in linters_by_ft,
--- because eligibility is per project and linters_by_ft is global.
---@param bufnr integer
---@return string[]
function M.php_linters(bufnr)
  return M.resolve(bufnr) and { "phpstan" } or {}
end

--- Whole-project run into the quickfix list. Per-file analysis on save catches
--- the file you're editing; this catches what your change broke elsewhere.
local function run_project(level)
  local ctx = M.resolve(0)
  if not ctx then
    return vim.notify(
      "phpstan: needs vendor/bin/phpstan and a phpstan.neon in the Laravel root",
      vim.log.levels.WARN
    )
  end

  local cmd = { ctx.bin }
  vim.list_extend(cmd, args(ctx))
  if level then vim.list_extend(cmd, { "--level", level }) end

  vim.notify("phpstan: analysing " .. vim.fn.fnamemodify(ctx.root, ":t") .. "…")
  -- clear = true so the agent markers stripped by clean_env() really are absent
  -- rather than merged back in from the parent environment.
  vim.system(cmd, { cwd = ctx.root, text = true, env = M.clean_env(), clear = true }, function(res)
    vim.schedule(function()
      local json = split_output(res.stdout or "")
      local ok, decoded = pcall(vim.json.decode, json or "")
      if not ok or type(decoded) ~= "table" then
        return vim.notify(
          "phpstan failed\n" .. vim.trim((res.stderr or "") .. (res.stdout or "")):sub(1, 500),
          vim.log.levels.ERROR
        )
      end

      local items = {}
      -- decoded.files is a JSON object keyed by path; nil when there are no
      -- errors at all (phpstan emits `"files": []` in that case).
      for path, file in pairs(decoded.files or {}) do
        for _, m in ipairs(file.messages or {}) do
          items[#items + 1] = {
            filename = path,
            lnum = type(m.line) == "number" and m.line or 1,
            col = 1,
            text = m.message,
            type = "E",
          }
        end
      end
      -- Not file-scoped (config errors, unmatched ignores).
      for _, m in ipairs((decoded.errors or {})) do
        items[#items + 1] = { filename = ctx.config, lnum = 1, col = 1, text = tostring(m), type = "E" }
      end

      if #items == 0 then
        return vim.notify("phpstan: no errors")
      end
      table.sort(items, function(a, b)
        if a.filename ~= b.filename then return a.filename < b.filename end
        return a.lnum < b.lnum
      end)
      vim.fn.setqflist({}, "r", { title = "phpstan", items = items })
      vim.cmd("copen")
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("LaravelPhpstan", function(opts)
    run_project(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Laravel: phpstan/larastan over the whole project into quickfix (optional level)",
  })
end

return M
