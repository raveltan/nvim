-- Nuxt/Vue behaviour, wired from the file that owns each concern (lsp.lua,
-- dap.lua, formatting.lua), like lua/artisan/ and lua/gaf/.
--
-- Module is `nuxtdev`, NOT `nuxt`: this config's lua/ heads the runtimepath, so
-- a lua/nuxt/ here would shadow the `nuxt` module of any plugin that ships one
-- (the trap that silently stopped laravel.nvim booting from lua/laravel/).
--
-- @vue/language-server v3 dropped takeover mode: vue_ls serves the SFC
-- template/style, and the <script> half needs vtsls with @vue/typescript-plugin
-- loaded. Neither half works alone.
local M = {}

local MASON_PKG = "vue-language-server"
local NUXT_CONFIG = { "nuxt.config.ts", "nuxt.config.mts", "nuxt.config.js", "nuxt.config.mjs" }

function M.root(bufnr)
  return vim.fs.root(bufnr or 0, NUXT_CONFIG)
end

function M.is_nuxt(bufnr)
  return M.root(bufnr) ~= nil
end

-- Resolution base tsserver probes for @vue/typescript-plugin. Deliberately the
-- server install, not the project's own node_modules: globalPlugins is one
-- global setting on a single vtsls instance serving every project in the
-- session, so a per-root path would be wrong for all but the first.
function M.vue_typescript_plugin_location()
  local mason = vim.fn.stdpath("data") .. "/mason/packages/" .. MASON_PKG .. "/node_modules/@vue/language-server"
  if vim.uv.fs_stat(mason) then return mason end
  local bin = vim.fn.exepath("vue-language-server")
  if bin == "" then return nil end
  local global = vim.fs.dirname(vim.fs.dirname(bin)) .. "/lib/node_modules/@vue/language-server"
  if vim.uv.fs_stat(global) then return global end
  return nil
end

-- nil when the server isn't installed yet: handing tsserver a path that doesn't
-- exist makes it log a load failure and carry on silently.
function M.vue_tsserver_plugin()
  local location = M.vue_typescript_plugin_location()
  if not location then return nil end
  return {
    name = "@vue/typescript-plugin",
    location = location,
    -- Required even though vtsls also lists the vue filetype: nvim picks the
    -- client by filetype, tsserver picks the plugin by language id.
    languages = { "vue" },
    configNamespace = "typescript",
  }
end

-- Auto-imports (useFetch/useState/definePageMeta), #app, #imports and the ~/
-- alias only exist in the generated .nuxt/ the app's tsconfig extends. Before
-- the first `nuxi prepare` every one of them is an unresolved symbol. Nuxt 3
-- writes .nuxt/tsconfig.json, Nuxt 4 splits it into tsconfig.app.json.
function M.prepared(root)
  root = root or M.root()
  if not root then return true end
  for _, name in ipairs({ "tsconfig.json", "tsconfig.app.json" }) do
    if vim.uv.fs_stat(root .. "/.nuxt/" .. name) then return true end
  end
  return false
end

-- Invoked through `node` rather than a package manager so nothing has to be
-- detected and no lockfile is touched.
local function nuxt_cli(root)
  local cli = root .. "/node_modules/nuxt/bin/nuxt.mjs"
  return vim.uv.fs_stat(cli) and cli or nil
end

function M.prepare(root, on_done)
  root = root or M.root()
  if not root then
    vim.notify("Not inside a Nuxt app (no nuxt.config.*)", vim.log.levels.WARN)
    return
  end
  local cli = nuxt_cli(root)
  if not cli then
    vim.notify("node_modules/nuxt not installed in " .. root .. " — install dependencies first", vim.log.levels.WARN)
    return
  end
  vim.notify("nuxi prepare: " .. vim.fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
  vim.system({ "node", cli, "prepare" }, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        vim.notify("nuxi prepare: done — restart vtsls (<leader>cR) to pick up .nuxt/", vim.log.levels.INFO)
      else
        vim.notify("nuxi prepare failed:\n" .. ((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
      end
      if on_done then on_done(res.code == 0) end
    end)
  end)
end

-- Paths resolve lazily (nvim-dap calls function values at launch) so the list
-- can be built at startup and still point at the app the buffer belongs to.
function M.dap_configurations()
  local function root_or_cwd()
    return M.root() or vim.fn.getcwd()
  end
  return {
    {
      type = "pwa-node",
      request = "launch",
      name = "Nuxt: debug dev server (SSR)",
      runtimeExecutable = "node",
      runtimeArgs = function()
        return { root_or_cwd() .. "/node_modules/nuxt/bin/nuxt.mjs", "dev" }
      end,
      cwd = root_or_cwd,
      console = "integratedTerminal",
      internalConsoleOptions = "neverOpen",
      autoAttachChildProcesses = true, -- nitro runs in a forked child; no SSR breakpoint binds without it
      sourceMaps = true,
      smartStep = true,
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    },
    {
      type = "pwa-node",
      request = "attach",
      name = "Nuxt: attach to dev server (--inspect, 9229)",
      port = 9229,
      cwd = root_or_cwd,
      restart = true, -- `nuxi dev` restarts nitro on every config change
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    },
    {
      type = "pwa-chrome",
      request = "launch",
      name = "Nuxt: Chrome (localhost:3000)",
      url = "http://localhost:3000",
      webRoot = root_or_cwd,
      sourceMaps = true,
    },
  }
end

local warned = {}

function M.setup()
  vim.api.nvim_create_user_command("NuxtPrepare", function()
    M.prepare()
  end, { desc = "Run nuxi prepare (regenerate .nuxt/ types)" })

  vim.api.nvim_create_user_command("NuxtDev", function()
    local root = M.root() or vim.fn.getcwd()
    Snacks.terminal("node node_modules/nuxt/bin/nuxt.mjs dev", { cwd = root })
  end, { desc = "Run the Nuxt dev server (Snacks terminal)" })

  -- Notify rather than auto-run: prepare executes the app's own config and its
  -- modules' hooks, which shouldn't be triggered by opening a file.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("nuxt_prepare_hint", { clear = true }),
    pattern = { "vue", "typescript", "javascript" },
    callback = function(args)
      local root = M.root(args.buf)
      if not root or warned[root] or M.prepared(root) then return end
      warned[root] = true
      vim.notify(".nuxt/ types missing — auto-imports will not resolve. Run :NuxtPrepare", vim.log.levels.WARN)
    end,
  })
end

return M
