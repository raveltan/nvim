-- Laravel plugins. Everything that decides *behaviour* (formatters, linters, dap
-- configs, LSP settings, blade completion sources) lives in lua/artisan/ and is
-- wired from the file that owns that concern, exactly like lua/gaf/ — this file
-- is only the third-party plugin.
--
-- The plugin is here strictly for what has to *drive* the application rather
-- than describe it: artisan, the make:* generators, Tinker, the route/model
-- pickers, the Eloquent code actions and the model/controller/composer virtual
-- text. Describing the application — completion and navigation for
-- view()/route()/config()/env()/__() strings, `<x-` and `<livewire:` tags,
-- @include targets — is laravel_lsp's job (lua/plugins/lsp.lua), which answers
-- from the booted app rather than a filesystem scan. Its blink source is
-- therefore not registered.
--
-- IMPORTANT: this config's own Laravel module lives in `lua/artisan/`, NOT
-- `lua/laravel/`. The config's `lua/` sits at the head of the runtimepath, so a
-- `lua/laravel/init.lua` here SHADOWS laravel.nvim's own entry point: the plugin
-- silently never boots, the `Laravel` global is never created, and every keymap
-- below errors. Do not rename the module back.
--
-- GAF gating is done by emptying the load triggers, NOT with `cond`/`enabled`.
-- lazy.nvim puts a cond=false plugin in `spec.disabled`, which means
-- `GAF=1 :Lazy clean` (or sync) would uninstall it — the same trap documented
-- for the GAF-only plugins in the other direction. With empty ft/keys the spec
-- stays installed and simply never fires.
local triggers = not vim.g.gaf

return {
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "folke/snacks.nvim",
    },
    ft = triggers and { "php", "blade" } or {},
    -- composer.json is often the first file opened in a fresh clone, and the
    -- version/outdated virtual text is what makes opening it useful.
    event = triggers and { "BufEnter composer.json" } or {},
    keys = triggers and {
      { "<leader>ll", function() Laravel.pickers.laravel() end,               desc = "Laravel: picker" },
      { "<leader>la", function() Laravel.pickers.artisan() end,               desc = "Laravel: artisan" },
      { "<leader>lr", function() Laravel.pickers.routes() end,                desc = "Laravel: routes" },
      { "<leader>lm", function() Laravel.pickers.make() end,                  desc = "Laravel: make" },
      { "<leader>lc", function() Laravel.pickers.commands() end,              desc = "Laravel: custom commands" },
      { "<leader>lo", function() Laravel.pickers.resources() end,             desc = "Laravel: resources" },
      { "<leader>lh", function() Laravel.run("artisan docs") end,             desc = "Laravel: documentation" },
      { "<leader>lt", function() Laravel.commands.run("actions") end,         desc = "Laravel: code actions" },
      { "<leader>lu", function() Laravel.commands.run("hub") end,             desc = "Laravel: artisan hub" },
      { "<leader>lp", function() Laravel.commands.run("command_center") end,  desc = "Laravel: command center" },
      { "<leader>lk", function() Laravel.commands.run("env:configure") end,   desc = "Laravel: configure environment" },
      -- The README maps this to <C-g>, which would shadow the built-in
      -- "show file info" in every buffer of every project, Laravel or not.
      { "<leader>lf", function() Laravel.commands.run("view:finder") end,     desc = "Laravel: view finder" },
    } or {},
    opts = {
      -- WARN, not the plugin's DEBUG default: at DEBUG it narrates every
      -- introspection call through vim.notify.
      debug_level = vim.log.levels.WARN,
      features = {
        pickers = {
          provider = "snacks",
        },
      },
      environments = {
        -- The environment is resolved from disk by lua/artisan/init.lua for
        -- formatting/linting/dap; prompting on every project open would ask a
        -- question the config can already answer. Change it per project with
        -- <leader>lk.
        ask_on_boot = false,
      },
    },
  },
}
