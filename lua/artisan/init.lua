-- Laravel project support.
--
-- Deliberately shaped differently from lua/gaf/: GAF is one checkout behind an
-- env flag (vim.g.gaf), so it can decide everything once at startup. Laravel is
-- "whatever project this buffer belongs to" — several can be open in one
-- session, and none may be open at all. So every entry point here resolves the
-- project from the *buffer's* path and returns nil when there isn't one. That
-- same nil is what keeps all of this inert inside fl-gaf (no `artisan` file), so
-- the GAF php-cs-fixer/phpcs/Docker-test pipeline is never touched.
local M = {}

-- dir -> root | false. vim.fs.root walks the tree on every call and these
-- helpers run per format, per lint, per completion keystroke — so misses are
-- cached as `false` too, not just hits.
local roots = {}

local function buf_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  -- Unnamed buffers and URI-style names (fugitive://, oil://, dbui) have no
  -- usable directory; fall back to cwd so :Laravel* commands still work from a
  -- scratch buffer.
  if name == "" or name:match("^%w%w+://") then return vim.fn.getcwd() end
  return vim.fs.dirname(name)
end

--- Nearest ancestor directory containing `artisan`.
---@param from string|integer|nil directory path, bufnr, or nil for the current buffer
---@return string|nil
function M.root(from)
  local dir = type(from) == "string" and from or buf_dir(from)
  local cached = roots[dir]
  if cached ~= nil then return cached or nil end
  local found = vim.fs.root(dir, "artisan")
  roots[dir] = found or false
  return found
end

---@param from string|integer|nil
---@return boolean
function M.is_laravel(from)
  return M.root(from) ~= nil
end

--- Executable lookup, in the order that keeps a project honest:
---   1. the project's own vendor/bin or node_modules/.bin — it matches
---      composer.json / package.json, so it is the version CI will use
---   2. mason — global fallback so a freshly cloned project still formats
---   3. $PATH
--- Returns an absolute path (never a bare relative one): a cwd-relative
--- "vendor/bin/pint" breaks the moment nvim wasn't started from the project
--- root, which is the same trap documented for phpcs in plugins/formatting.lua.
---@param name string
---@param root string|nil
---@return string|nil
function M.bin(name, root)
  root = root or M.root()
  if root then
    for _, dir in ipairs({ "/vendor/bin/", "/node_modules/.bin/" }) do
      local p = root .. dir .. name
      if vim.uv.fs_stat(p) then return p end
    end
  end
  local mason = vim.fn.stdpath("data") .. "/mason/bin/" .. name
  if vim.uv.fs_stat(mason) then return mason end
  if vim.fn.executable(name) == 1 then return vim.fn.exepath(name) end
  return nil
end

--- How this project runs php. Mirrors laravel.nvim's environment list, but
--- resolved from disk rather than from its stored per-project choice: conform,
--- nvim-lint and nvim-dap all need an answer before any laravel.nvim code has
--- been loaded.
---
--- Note this is only consulted for things that must run *inside* the app
--- (artisan, tests, xdebug path mappings). Formatters and static analysers are
--- deliberately run on the host instead — pint and phpstan are plain PHP and
--- work fine there, and routing them through `sail` would make every save wait
--- on a docker exec and fail outright when the containers are down.
---@param root string|nil
---@return "sail"|"docker"|"local"
function M.env(root)
  root = root or M.root()
  if not root then return "local" end
  -- The compose file is the real signal, not vendor/bin/sail: laravel/sail is a
  -- dependency of the default skeleton, so the binary exists in every project
  -- whether or not it was ever `sail:install`ed. Keying on the binary alone made
  -- plain Herd/`artisan serve` projects report "sail" and route every artisan
  -- call through a container that isn't there.
  local compose = vim.uv.fs_stat(root .. "/docker-compose.yml")
    or vim.uv.fs_stat(root .. "/docker-compose.yaml")
    or vim.uv.fs_stat(root .. "/compose.yaml")
    or vim.uv.fs_stat(root .. "/compose.yml")
  if not compose then return "local" end
  if vim.uv.fs_stat(root .. "/vendor/bin/sail") then return "sail" end
  return "docker"
end

--- Argv prefix that runs `php` for this project.
---@param root string|nil
---@return string[]
function M.php_cmd(root)
  root = root or M.root()
  local env = M.env(root)
  if env == "sail" then return { (root or ".") .. "/vendor/bin/sail", "php" } end
  if env == "docker" then return { "docker", "compose", "exec", "-T", "app", "php" } end
  return { "php" }
end

--- Argv prefix that runs `artisan` for this project.
---@param root string|nil
---@return string[]
function M.artisan_cmd(root)
  root = root or M.root()
  local cmd = M.php_cmd(root)
  -- Under sail/docker the app lives at the container's own path, so `artisan`
  -- must stay relative and be resolved by the container's working directory.
  cmd[#cmd + 1] = M.env(root) == "local" and ((root or ".") .. "/artisan") or "artisan"
  return cmd
end

--- Run an artisan subcommand in a Snacks terminal rooted at the project.
--- Same shape as the :RailsConsole helper in plugins/rails.lua.
---@param subcommand string
function M.artisan(subcommand)
  local root = M.root()
  if not root then
    return vim.notify("Not in a Laravel project (no artisan found)", vim.log.levels.WARN)
  end
  local cmd = M.artisan_cmd(root)
  cmd[#cmd + 1] = subcommand
  Snacks.terminal(cmd, { cwd = root })
end

function M.setup()
  -- fl-gaf is PHP but not Laravel; skip the whole module rather than relying on
  -- every individual root() call to come back nil.
  if vim.g.gaf then return end

  require("artisan.ide_helper").setup()
  require("artisan.lint").setup()
  require("artisan.livewire").setup()
  require("artisan.gf").setup()
  require("artisan.gd").setup()

  vim.api.nvim_create_user_command("LaravelArtisan", function(opts)
    M.artisan(opts.args)
  end, { nargs = "+", desc = "Laravel: run an artisan command in a terminal" })

  vim.api.nvim_create_user_command("LaravelRoot", function()
    local root = M.root()
    vim.notify(root and ("Laravel root: " .. root) or "Not in a Laravel project")
  end, { desc = "Laravel: report the detected project root" })
end

return M
