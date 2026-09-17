-- Cursor Tab (next-edit prediction + cursor jumps) inside nvim. It talks to
-- Cursor's own StreamCpp backend through a Python sidecar and authenticates by
-- reading the local Cursor app session — no API key, no extra subscription, but
-- it does require /Applications/Cursor.app to be installed and signed in.
-- Beta, and it rides an undocumented private API: expect it to break when
-- Cursor changes the backend.
--
-- Off until asked for: <leader>ua toggles it (lua/gaf/neocursor.lua). Nothing
-- loads before that press, so a session that does not want ghost text pays no
-- sidecar and sees no backend warnings.
--
-- GAF-only. Gating is done by emptying the load trigger, NOT with
-- `cond`/`enabled`: lazy.nvim puts a cond=false plugin in `spec.disabled`, so a
-- plain `:Lazy clean` would uninstall it (same trap as laravel.nvim, in the
-- other direction). With `event = {}` the spec stays installed and never fires
-- — and an empty table still counts as a lazy handler, so the plugin is not
-- loaded at startup either.
local triggers = vim.g.gaf

return {
  {
    "teocns/neocursor.nvim",
    version = "*", -- tagged releases; main is beta and moves. Drop for latest.
    event = {},
    -- Materialise the sidecar's uv env at install time instead of paying for it
    -- on the first keystroke of the first insert of the session.
    build = 'uv run --with "httpx[http2]" python -c "import httpx"',
    opts = {
      -- blink.cmp owns <Tab> (lua/plugins/lsp.lua); its chain calls
      -- neocursor.accept() first, so a second mapping here would shadow it.
      map_tab = false,
    },
    -- setup() is routed through the toggle module so a re-enable can replay the
    -- same opts without lazy loading the spec a second time.
    config = function(_, opts) require("gaf.neocursor").activate(opts) end,
    -- Registered via the Snacks.toggle registry (deferred to VeryLazy, when the
    -- registry exists) for the which-key on/off state, same as the <leader>u
    -- toggles in lua/plugins/snacks.lua.
    init = triggers and function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          Snacks.toggle
            .new({
              name = "Cursor Tab",
              get = function() return require("gaf.neocursor").enabled() end,
              set = function(state)
                local neocursor = require("gaf.neocursor")
                if state then neocursor.enable() else neocursor.disable() end
              end,
            })
            :map("<leader>ua")
        end,
      })
    end or nil,
  },
}
