-- Cursor Tab (next-edit prediction + cursor jumps) inside nvim. It talks to
-- Cursor's own StreamCpp backend through a Python sidecar and authenticates by
-- reading the local Cursor app session — no API key, no extra subscription, but
-- it does require /Applications/Cursor.app to be installed and signed in.
-- Beta, and it rides an undocumented private API: expect it to break when
-- Cursor changes the backend.
--
-- GAF-only. Gating is done by emptying the load trigger, NOT with
-- `cond`/`enabled`: lazy.nvim puts a cond=false plugin in `spec.disabled`, so a
-- plain `:Lazy clean` would uninstall it (same trap as laravel.nvim, in the
-- other direction). With `event = {}` the spec stays installed and never fires.
local triggers = vim.g.gaf

return {
  {
    "teocns/neocursor.nvim",
    version = "*", -- tagged releases; main is beta and moves. Drop for latest.
    event = triggers and "InsertEnter" or {},
    -- Materialise the sidecar's uv env at install time instead of paying for it
    -- on the first keystroke of the first insert of the session.
    build = 'uv run --with "httpx[http2]" python -c "import httpx"',
    opts = {
      -- blink.cmp owns <Tab> (lua/plugins/lsp.lua); its chain calls
      -- neocursor.accept() first, so a second mapping here would shadow it.
      map_tab = false,
    },
  },
}
