-- Reads fl-gaf's .arclint so the editor reports PHP lint the same way
-- `arc lint` does. Two things live there that nvim-lint has no concept of:
--
--   1. the file->ruleset split: src2/ is linted by the `phpcs-src2` linter with
--      phpcs_gaf-src2.xml, everything else by `phpcs` with phpcs_gaf.xml.
--   2. per-sniff severity overrides, which fl-gaf uses heavily — 16 sniffs on
--      the non-src2 linter and 1 on src2 are downgraded to "advice", i.e. arc
--      shows them but they never block. phpcs itself still emits them as
--      errors, so without this map the editor paints 16 red errors that arc
--      considers ignorable noise.
--
-- Parsed from the file rather than transcribed into Lua so the two cannot
-- drift; a repo-side change to .arclint takes effect on the next save.
local paths = require("gaf.paths")

local M = {}

-- Arc's five severities (ArcanistLintSeverity) mapped onto vim's four.
-- "disabled" has no counterpart: arc drops the message entirely, so the parser
-- treats a nil severity as "discard this diagnostic".
local ARC_TO_VIM = {
  error = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  autofix = vim.diagnostic.severity.INFO,
  advice = vim.diagnostic.severity.HINT,
  disabled = false,
}

local cache = { mtime = nil, data = nil }

-- Decoded .arclint, or nil. Re-read only when the file's mtime moves; a broken
-- or missing .arclint yields nil and every caller degrades to "no overrides"
-- rather than erroring on every save.
local function config()
  local file = paths.fl_gaf .. "/.arclint"
  local stat = vim.uv.fs_stat(file)
  if not stat then
    cache = { mtime = nil, data = nil }
    return nil
  end
  local mtime = stat.mtime.sec
  if cache.mtime == mtime then return cache.data end
  local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
  end)
  cache = { mtime = mtime, data = ok and decoded or nil }
  return cache.data
end

--- Name of the .arclint linter block that owns `relpath`.
--- Mirrors the include/exclude regexes of the two flarc-phpcs linters. Kept as
--- plain prefix tests instead of translated PCRE: the patterns involved are
--- anchored literals, and a general PCRE->Lua translation would be a far bigger
--- liability than the two lines it saves.
function M.phpcs_linter(relpath)
  if not relpath then return "phpcs" end
  return vim.startswith(relpath, "src2/") and "phpcs-src2" or "phpcs"
end

--- phpcs standard (ruleset xml) for `relpath`, as an absolute path.
function M.phpcs_standard(relpath)
  local linter = M.phpcs_linter(relpath)
  local conf = config()
  local standard = conf
    and conf.linters
    and conf.linters[linter]
    and conf.linters[linter]["phpcs.standard"]
  return paths.fl_gaf .. "/" .. (standard or "phpcs_gaf.xml")
end

--- True when arc lints `relpath` with phpcs at all.
--- support/flarc is PHP 7.4 (excluded from the `phpcs` linter, and not matched
--- by `phpcs-src2`), and the two phpstan baselines are excluded repo-wide.
function M.phpcs_applies(relpath)
  if not relpath then return false end
  if not relpath:match("%.php$") then return false end
  if vim.startswith(relpath, "support/flarc/") then return false end
  if relpath == "phpstan-baseline.php" or relpath == "phpstan-baseline-src2.php" then return false end
  return true
end

--- Severity overrides for `relpath`'s linter: { ["PHPCS.E.<sniff>"] = <vim
--- severity or false> }. `false` means arc has the sniff disabled.
--- Only the exact-match `severity` map is honoured. .arclint also supports
--- `severity.rules` (regex keys); fl-gaf sets none for phpcs, and silently
--- half-applying it would be worse than ignoring it.
function M.phpcs_severities(relpath)
  local conf = config()
  local block = conf and conf.linters and conf.linters[M.phpcs_linter(relpath)]
  local raw = block and block.severity
  if not raw then return {} end
  local map = {}
  for code, arc in pairs(raw) do
    local severity = ARC_TO_VIM[arc]
    if severity ~= nil then map[code] = severity end
  end
  return map
end

return M
