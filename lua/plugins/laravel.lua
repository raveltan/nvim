-- Laravel plugins. Everything that decides *behaviour* (formatters, linters, dap
-- configs, LSP settings, blade completion sources) lives in lua/artisan/ and is
-- wired from the file that owns that concern, exactly like lua/gaf/ — this file
-- is only the two third-party plugins.
--
-- Division of labour between them:
--   laravel.nvim  — pickers, artisan, tinker, model/route virtual text, code
--                   actions, and completion for the *strings* inside view(),
--                   route(), config(), env(), Inertia::render() and Eloquent
--                   column names.
--   blade-nav     — `gf` and completion for Blade *references*: @include,
--                   <x-component>, <livewire:…>, @livewire('…'), Inertia pages.
--
-- Both ship a `gf`, and letting either one own the key is broken: blade-nav
-- replays the previous global mapping on a miss, which for laravel.nvim's
-- callback-only `expr` map meant every unresolved `gf` in a php/blade buffer —
-- plain file paths included — raised `E5108`. Both registrations are therefore
-- switched off here and the chain is made explicit in lua/artisan/gf.lua.
--
-- IMPORTANT: this config's own Laravel module lives in `lua/artisan/`, NOT
-- `lua/laravel/`. The config's `lua/` sits at the head of the runtimepath, so a
-- `lua/laravel/init.lua` here SHADOWS laravel.nvim's own entry point: the plugin
-- silently never boots, the `Laravel` global is never created, and every keymap
-- below errors. Do not rename the module back.
--
-- GAF gating is done by emptying the load triggers, NOT with `cond`/`enabled`.
-- lazy.nvim puts a cond=false plugin in `spec.disabled`, which means
-- `GAF=1 :Lazy clean` (or sync) would uninstall both of these — the same trap
-- documented for the GAF-only plugins in the other direction. With empty
-- ft/keys the specs stay installed and simply never fire.
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

  {
    "RicardoRamirezR/blade-nav.nvim",
    ft = triggers and { "blade", "php" } or {},
    keys = triggers and {
      { "<leader>lv", "<cmd>BladeNavToggleShowValues<cr>", desc = "BladeNav: toggle config/env annotations" },
      { "<leader>lC", "<cmd>BladeNavClearCache<cr>",       desc = "BladeNav: clear cache" },
    } or {},
    opts = {
      annotations = {
        -- Off by default upstream, but its keymaps are NOT: create_keymaps
        -- claims a global `K` (clobbering LSP hover everywhere, not just in
        -- blade) plus <leader>bv / <leader>bcc, which collide with the buffer
        -- group. The two commands are mapped under <leader>l above instead.
        create_keymaps = false,
      },
      integrations = {
        -- lua/artisan/gf.lua owns the key and calls blade-nav's resolver as one
        -- step of an explicit chain; see the note at the top of this file.
        gf = false,
        -- This config uses blink.cmp. Left on, blade-nav's cmp integration
        -- warns "[BladeNav Warn] nvim-cmp not found, skipping BladeNav cmp
        -- source setup." on every load, and its coq integration is dead weight.
        -- The blink source is registered by hand in lua/plugins/lsp.lua.
        cmp = false,
        coq = false,
      },
      handlers = {
        -- All three verified broken against Laravel 13 / Livewire 4 and
        -- answered by lua/artisan/ instead:
        --   livewire  — scans only resources/views/livewire, so it found 1 of
        --               the 4 components in a stock Livewire 4 app
        --   component — scans ALL of resources/views/components, so it offered
        --               `<x-admin.⚡user-table />`, not a valid tag
        --   route     — shells out `artisan route:list --columns=…`, an option
        --               Laravel 13 removed; returns nothing. laravel.nvim's own
        --               route completion works and stays.
        livewire = false,
        component = false,
        route = false,
      },
    },
    -- setup() itself bails when the project has no artisan/composer.json, so
    -- nothing else needs gating here.
  },
}
