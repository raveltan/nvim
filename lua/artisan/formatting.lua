-- conform.nvim entries for Laravel projects. Wired into the non-GAF branch of
-- lua/plugins/formatting.lua.
--
-- Every formatter here is condition-guarded on the project actually shipping the
-- tool, for two reasons: a global `pint` on $PATH must never reformat an
-- unrelated PHP repo to Laravel's style, and blade only ever exists in a Laravel
-- checkout anyway. When no condition matches, conform falls through to
-- `lsp_format = "fallback"` (plugins/formatting.lua) and intelephense formats.
local laravel = require("artisan")

local M = {}

-- conform passes ctx.dirname (the buffer's directory), so resolution is
-- per buffer: one session can format a Laravel repo with pint and a plain PHP
-- repo with php-cs-fixer without any global state.
local function project_bin(name, ctx)
  local root = laravel.root(ctx.dirname)
  if not root then return nil end
  return laravel.bin(name, root), root
end

---@return table conform formatter overrides, merged over the builtins
function M.formatters()
  return {
    -- pint IS php-cs-fixer with Laravel's ruleset baked in. The builtin already
    -- finds vendor/bin/pint by walking up from the buffer; the condition is what
    -- stops a globally-installed pint from touching non-Laravel PHP.
    pint = {
      condition = function(_, ctx)
        return project_bin("pint", ctx) ~= nil
      end,
      cwd = function(_, ctx)
        return laravel.root(ctx.dirname)
      end,
    },

    -- Fallback for Laravel projects that predate pint and still carry a
    -- php-cs-fixer config. Guarded on the config file, not just the binary:
    -- php-cs-fixer with no config rewrites to its own default ruleset.
    php_cs_fixer = {
      condition = function(_, ctx)
        local root = laravel.root(ctx.dirname)
        if not root then return false end
        for _, name in ipairs({ ".php-cs-fixer.php", ".php-cs-fixer.dist.php", ".php_cs", ".php_cs.dist" }) do
          if vim.uv.fs_stat(root .. "/" .. name) then return true end
        end
        return false
      end,
    },

    -- The builtin only looks for `blade-formatter` on $PATH, which misses the
    -- common case of it being a project devDependency. Resolve it properly.
    ["blade-formatter"] = {
      command = function(_, ctx)
        return (project_bin("blade-formatter", ctx)) or "blade-formatter"
      end,
      condition = function(_, ctx)
        return project_bin("blade-formatter", ctx) ~= nil
      end,
      cwd = function(_, ctx)
        return laravel.root(ctx.dirname)
      end,
    },
  }
end

---@return table<string, string[]> conform formatters_by_ft additions
function M.formatters_by_ft()
  return {
    php = { "pint", "php_cs_fixer", stop_after_first = true },
    blade = { "blade-formatter" },
  }
end

return M
