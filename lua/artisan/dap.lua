-- Xdebug configurations for Laravel projects.
--
-- The adapter itself (`dap.adapters.php`) is already registered by
-- mason-nvim-dap's default_setup — `php` is in its ensure_installed list in
-- plugins/dap.lua. Only the configurations are missing outside GAF, which is why
-- <leader>dc on a php buffer previously offered nothing.
local laravel = require("artisan")

local M = {}

-- Keep the debugger out of the framework. Without this, "break on exception" or
-- a stray step-into lands in Illuminate internals on nearly every request.
local IGNORE = { "**/vendor/**/*.php" }

-- Defaults are tiny (max_children 32, max_data 1024), which truncates Eloquent
-- models and collections into uselessness in the scopes view.
local XDEBUG_SETTINGS = {
  max_children = 512,
  max_data = 8192,
  max_depth = 5,
}

function M.configurations()
  return {
    {
      type = "php",
      request = "launch",
      name = "Xdebug: listen (:9003)",
      port = 9003,
      log = false,
      stopOnEntry = false,
      ignore = IGNORE,
      xdebugSettings = XDEBUG_SETTINGS,
      -- No pathMappings on purpose. Herd, Valet, `php artisan serve` and a
      -- plain CLI run all report the same absolute paths the editor sees; a
      -- mapping here would silently unbind every breakpoint.
    },
    {
      type = "php",
      request = "launch",
      name = "Xdebug: listen (:9003) — Sail/Docker",
      port = 9003,
      log = false,
      stopOnEntry = false,
      ignore = IGNORE,
      xdebugSettings = XDEBUG_SETTINGS,
      -- Sail's container path. `docker compose` setups built from the Laravel
      -- skeleton use the same one; change the key if yours differs.
      pathMappings = {
        ["/var/www/html"] = "${workspaceFolder}",
      },
    },
    {
      type = "php",
      request = "launch",
      name = "Xdebug: launch current file",
      program = "${file}",
      cwd = "${workspaceFolder}",
      port = 9003,
      ignore = IGNORE,
      xdebugSettings = XDEBUG_SETTINGS,
      -- Forced on the command line so the project's php.ini doesn't have to
      -- have xdebug.start_with_request enabled globally (which would slow every
      -- unrelated php invocation down).
      runtimeArgs = {
        "-dxdebug.mode=debug",
        "-dxdebug.start_with_request=yes",
        "-dxdebug.client_port=9003",
      },
    },
    {
      type = "php",
      request = "launch",
      name = "Xdebug: launch artisan command",
      program = "${workspaceFolder}/artisan",
      cwd = "${workspaceFolder}",
      port = 9003,
      ignore = IGNORE,
      xdebugSettings = XDEBUG_SETTINGS,
      runtimeArgs = {
        "-dxdebug.mode=debug",
        "-dxdebug.start_with_request=yes",
        "-dxdebug.client_port=9003",
      },
      args = function()
        local input = vim.fn.input("artisan ")
        return vim.split(vim.trim(input), "%s+", { trimempty = true })
      end,
    },
  }
end

--- Start the listener that matches this project's environment, skipping the
--- config picker. Sail/docker projects need the path mapping; everything else
--- must not have one.
local function listen()
  local dap = require("dap")
  local wanted = laravel.env() == "local" and "Xdebug: listen (:9003)"
    or "Xdebug: listen (:9003) — Sail/Docker"
  for _, config in ipairs(dap.configurations.php or {}) do
    if config.name == wanted then
      return dap.run(config)
    end
  end
  vim.notify("No php dap configuration named " .. wanted, vim.log.levels.ERROR)
end

function M.keys()
  return {
    { "<leader>dp", listen, desc = "Xdebug: listen (auto env)" },
    {
      "<leader>dP",
      function()
        require("dap").continue() -- config picker
      end,
      desc = "Xdebug: pick a php configuration",
    },
  }
end

function M.setup()
  -- Assigned directly rather than from a FileType autocmd, for the reason
  -- documented in lua/gaf/dap.lua: neotest's dap strategy needs
  -- dap.configurations.php populated even when DAP loads after the php buffer.
  require("dap").configurations.php = M.configurations()
end

return M
