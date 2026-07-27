-- barryvdh/laravel-ide-helper generation.
--
-- What each generator is actually worth, measured against intelephense on
-- Laravel 13 with a cold index (not assumed from the package's README):
--
--   ide-helper:models -M  -> _ide_helper_models.php + one `@mixin` line per
--        model. THE one that matters. Before: `$user->email`,
--        `User::whereEmail(…)` and `$user->notifications_count` all resolve to
--        nothing. After: all three resolve.
--   ide-helper:meta       -> .phpstorm.meta.php, container binding return types.
--        Cheap, occasionally helps `app()`/`resolve()` call sites.
--   ide-helper:generate   -> _ide_helper.php, facade signatures. NOT run by
--        default: modern Laravel ships `@method static` docblocks on the facade
--        classes themselves (100 of them on Illuminate\Support\Facades\Route),
--        so `Route::get` already resolves cold. Generating it adds a ~1 MB file
--        to the index and gives every facade call a duplicate go-to-definition
--        target. Ask for it explicitly (`:LaravelIdeHelper facades`) if a
--        third-party package ships facades without docblocks.
--
-- lua/artisan/lsp.lua deliberately does not exclude any of those paths.
local laravel = require("artisan")

local M = {}

local STEPS = {
  facades = { "ide-helper:generate" },
  -- -M writes the `@mixin` docblock into each model (one line, idempotent)
  -- instead of dumping the whole generated class into the model file. -n keeps
  -- it non-interactive; without it the command blocks on a confirmation prompt
  -- and vim.system waits forever.
  models = { "ide-helper:models", "-M", "-n" },
  meta = { "ide-helper:meta" },
}

-- Default run. `facades` is deliberately absent — see the note above.
local ORDER = { "models", "meta" }
local ALL = { "facades", "models", "meta" }

local function installed(root)
  return vim.uv.fs_stat(root .. "/vendor/barryvdh/laravel-ide-helper") ~= nil
end

local function restart_intelephense()
  -- The generators just wrote files the server has already indexed as absent.
  -- A restart is the only reliable way to get them picked up; intelephense has
  -- no "reindex workspace" request.
  local buffers = {}
  for _, client in ipairs(vim.lsp.get_clients({ name = "intelephense" })) do
    for bufnr in pairs(client.attached_buffers) do
      if vim.api.nvim_buf_is_loaded(bufnr) then buffers[#buffers + 1] = bufnr end
    end
    client:stop(true) -- vim.lsp.stop_client() is deprecated on 0.12
  end
  -- Re-attach rather than `:edit`. Reloading the buffer prompts
  -- "Save changes to …?" whenever there are unsaved edits (options.lua sets
  -- `confirm`), which is a terrible way to end a background codegen task.
  vim.defer_fn(function()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("LspStart intelephense") end)
      end
    end
  end, 500)
end

--- Run the steps one after another; a generator that fails aborts the rest,
--- since models depends on facades having produced a loadable app.
local function run(root, steps, index)
  index = index or 1
  local name = steps[index]
  if not name then
    vim.notify("ide-helper: done, restarting intelephense")
    return restart_intelephense()
  end

  local cmd = laravel.artisan_cmd(root)
  vim.list_extend(cmd, STEPS[name])

  vim.notify("ide-helper: " .. name .. "…")
  vim.system(cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return vim.notify(
          "ide-helper:" .. name .. " failed\n" .. vim.trim((res.stderr or "") .. (res.stdout or "")):sub(1, 500),
          vim.log.levels.ERROR
        )
      end
      run(root, steps, index + 1)
    end)
  end)
end

local function install_then_run(root, steps)
  vim.notify("ide-helper: installing barryvdh/laravel-ide-helper…")
  local cmd = { "composer", "require", "--dev", "--no-interaction", "barryvdh/laravel-ide-helper" }
  vim.system(cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return vim.notify(
          "composer require failed\n" .. vim.trim((res.stderr or "") .. (res.stdout or "")):sub(1, 500),
          vim.log.levels.ERROR
        )
      end
      run(root, steps)
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("LaravelIdeHelper", function(opts)
    local root = laravel.root()
    if not root then
      return vim.notify("Not in a Laravel project (no artisan found)", vim.log.levels.WARN)
    end

    local steps = ORDER
    if opts.args ~= "" then
      if not STEPS[opts.args] then
        return vim.notify("Unknown step: " .. opts.args, vim.log.levels.ERROR)
      end
      steps = { opts.args }
    end

    if installed(root) then
      return run(root, steps)
    end
    -- Adding a dev dependency edits composer.json/lock, so ask first.
    vim.ui.select({ "yes", "no" }, {
      prompt = "barryvdh/laravel-ide-helper is not installed. composer require --dev it?",
    }, function(choice)
      if choice == "yes" then install_then_run(root, steps) end
    end)
  end, {
    nargs = "?",
    complete = function()
      return vim.deepcopy(ALL)
    end,
    desc = "Laravel: generate IDE helper files (models+meta by default; `facades` on request)",
  })
end

return M
