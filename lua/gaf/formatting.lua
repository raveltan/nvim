local arclint = require("gaf.arclint")
local paths = require("gaf.paths")

local M = {}

-- Partial override, merged over conform's builtin php_cs_fixer (inherit=true
-- default): stdin=false and the rest come from the builtin; only the fl-gaf
-- binary and --config differ. args stays explicit because the options must
-- follow the `fix` subcommand (prepend_args would put them before it).
function M.php_cs_fixer_formatter()
  return {
    command = paths.fl_gaf .. "/support/php-cs-fixer/vendor/bin/php-cs-fixer",
    args = function(_, ctx)
      -- src2 has its own config: .php-cs-fixer.dist.php's Finder excludes src2,
      -- but --path-mode defaults to `override` so an explicit $FILENAME is
      -- formatted anyway — with the wrong ruleset, missing the six src2-only
      -- rules (global_namespace_import, ordered_class_elements, ...). Saving
      -- then diverged from `composer fix:php-cs-fixer:all`.
      local relpath = paths.gaf_relpath(ctx.buf)
      local config = (relpath and vim.startswith(relpath, "src2/"))
          and "/.php-cs-fixer-src2.dist.php"
        or "/.php-cs-fixer.dist.php"
      return {
        "fix",
        "--config=" .. paths.fl_gaf .. config,
        "--no-interaction",
        "--quiet",
        "$FILENAME",
      }
    end,
    -- Both configs are cwd-sensitive even though --path-mode defaults to
    -- `override`: the Finder is still constructed, and the src2 one does
    -- `->in('src2')`, which aborts with `The "src2" directory does not exist`
    -- from anywhere else. It also puts the .cache/php-cs-fixer/ files inside
    -- the repo, where CI expects them, instead of wherever nvim was started.
    cwd = function() return paths.fl_gaf end,
  }
end

-- nvim-lint evaluates function *elements* of an args list per run (a function
-- used as `args` itself is silently dropped and phpcs would run bare), so the
-- per-buffer ruleset choice has to be one entry rather than a computed table.
function M.phpcs_args()
  return {
    "-q",
    "--report=json",
    function() return "--standard=" .. arclint.phpcs_standard(paths.gaf_relpath(0)) end,
    -- Restores what nvim-lint's builtin passes and this override used to drop.
    -- Without it phpcs sees the buffer as "STDIN" with no path, so every
    -- <exclude-pattern> in the rulesets (vendor/*, src2/Traits/GafThrift/*,
    -- src/Core/Test/Thrift/ApiClient/*) stops matching. Repo-relative, matching
    -- how the rulesets and .arclint express paths.
    function() return "--stdin-path=" .. (paths.gaf_relpath(0) or vim.fn.expand("%:p")) end,
    "-", -- phpcs requires this last for stdin
  }
end

--- Wraps nvim-lint's builtin phpcs parser with .arclint's severity overrides.
--- The builtin maps phpcs ERROR/WARNING straight onto vim ERROR/WARN, which
--- paints 16 sniffs red that arc treats as advice. Reconstructs arc's message
--- code (`PHPCS.E.<sniff>` / `PHPCS.W.<sniff>`, per FlarcPhpcsLinter) from the
--- diagnostic and re-grades it; sniffs arc disables are dropped.
function M.phpcs_parser(builtin)
  return function(output, bufnr, ...)
    local diagnostics = builtin(output, bufnr, ...)
    local severities = arclint.phpcs_severities(paths.gaf_relpath(bufnr))
    if vim.tbl_isempty(severities) then return diagnostics end
    local kept = {}
    for _, d in ipairs(diagnostics) do
      local prefix = d.severity == vim.diagnostic.severity.ERROR and "E" or "W"
      local override = severities["PHPCS." .. prefix .. "." .. (d.code or "")]
      if override ~= false then
        if override then d.severity = override end
        table.insert(kept, d)
      end
    end
    return kept
  end
end

return M
