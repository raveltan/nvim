-- neotest wiring for PHP.
--
-- Pest wraps PHPUnit but is not compatible with the phpunit adapter (different
-- --filter syntax, different result file), and neotest-pest's `is_test_file`
-- claims any `*Test.php` — so exactly one of them must answer for a given file.
--
-- That choice is made PER FILE, not once at setup. An earlier version decided it
-- from cwd when the neotest spec was evaluated, which broke badly: opening
-- `nvim ~/project/tests/Feature/FooTest.php` from a different directory
-- registered the phpunit adapter rooted at the wrong place, and running a test
-- failed with `E475: 'vendor/bin/phpunit' is not executable` — silently wrong
-- rather than merely suboptimal.
local M = {}

-- Absolute path of the cobertura file to write while a coverage run is in
-- flight, else nil. neotest-pest's build_spec ignores `extra_args`, `env` and
-- `cwd` entirely, so coverage flags can only reach pest through `pest_cmd`.
local coverage_target = nil

--- True when `root` is a Pest-driven project. `tests/Pest.php` is what
--- neotest-pest itself uses as its root marker, so agreeing with it here keeps
--- adapter selection and adapter rooting from disagreeing.
---
--- Takes the root explicitly and never falls back: a nil root means "this file
--- belongs to no Laravel project", which must answer false. (An `or` fallback
--- here silently substituted the *current buffer's* root, so the pest adapter
--- claimed test files in unrelated PHP projects.)
---@param root string|nil
---@return boolean
function M.is_pest_root(root)
  return root ~= nil and vim.uv.fs_stat(root .. "/tests/Pest.php") ~= nil
end

--- Convenience wrapper for the current buffer.
---@return boolean
function M.uses_pest()
  return M.is_pest_root(require("artisan").root())
end

--- Both PHP adapters, each gated so only one can claim any given file:
--- pest inside a Pest project, phpunit everywhere else (including plain
--- non-Laravel PHP, where `root()` is nil and there is no Pest.php).
---@return table[]
function M.php_adapters()
  local pest = require("neotest-pest")(M.pest_opts())
  local phpunit = require("neotest-phpunit")({
    phpunit_cmd = function()
      local laravel = require("artisan")
      return laravel.bin("phpunit", laravel.root()) or "vendor/bin/phpunit"
    end,
  })
  return { M.gate(pest, true), M.gate(phpunit, false) }
end

--- Wrap an adapter so `is_test_file` additionally requires the file's project to
--- match (or not match) the Pest shape.
---@param adapter table
---@param want_pest boolean
---@return table
function M.gate(adapter, want_pest)
  local wrapped = vim.tbl_extend("force", {}, adapter)
  local inner = adapter.is_test_file
  wrapped.is_test_file = function(file)
    if not inner(file) then return false end
    local root = require("artisan").root(vim.fs.dirname(file))
    return M.is_pest_root(root) == want_pest
  end
  return wrapped
end

--- Options for neotest-pest.
---@return table
function M.pest_opts()
  return {
    parallel = vim.g.laravel_pest_parallel or 0,
    ignore_dirs = { "vendor", "node_modules", "storage", "bootstrap" },
    -- The adapter's default is the *relative* "vendor/bin/pest" and it sets no
    -- cwd on the spec, so it only works when nvim was started from the project
    -- root. Resolve absolutely instead.
    pest_cmd = function()
      local laravel = require("artisan")
      local root = laravel.root()
      local cmd = { laravel.bin("pest", root) or "vendor/bin/pest" }
      if coverage_target then
        vim.list_extend(cmd, { "--coverage", "--coverage-cobertura=" .. coverage_target })
      end
      return cmd
    end,
  }
end

--- Ask the next pest run to emit cobertura coverage to `path` (absolute).
--- Driven by lua/config/neotest-coverage.lua; cleared when that run settles.
---@param path string|nil
function M.set_coverage(path)
  coverage_target = path
end

--- Whether pest can actually collect coverage here. Without xdebug or pcov, pest
--- writes no report at all and the coverage poll would sit there until it times
--- out — so this is checked up front and reported instead. Cached: it shells out.
---@return boolean ok
---@return string|nil reason
local coverage_driver = nil
function M.coverage_available()
  if coverage_driver == nil then
    local res = vim.system({ "php", "-m" }, { text = true }):wait()
    local mods = (res.stdout or ""):lower()
    coverage_driver = mods:find("xdebug", 1, true) ~= nil or mods:find("pcov", 1, true) ~= nil
  end
  if coverage_driver then return true end
  return false, "pest coverage needs the xdebug or pcov extension; php -m shows neither"
end

return M
