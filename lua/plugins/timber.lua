-- Print/log-injection debugging. Treesitter-aware log insertion for the
-- variable under the cursor (or visual selection).
--
-- Primary keybind (use every time):
--   <leader>ll  log var under cursor / visual selection, BELOW the line
-- Always inserts below. Default `gl*` keymaps are disabled — everything lives
-- under the <leader>l group.
return {
  {
    "Goose97/timber.nvim",
    version = "*",
    event = "VeryLazy", -- load early so the neotest log-watcher is armed before any test run
    keys = {
      {
        "<leader>ll",
        function() require("timber.actions").insert_log({ position = "below" }) end,
        mode = { "n", "v" },
        desc = "Timber: log var below",
      },
      { "<leader>ls", function() require("timber.summary").open() end, desc = "Timber: log summary panel" },
      { "<leader>lc", function() require("timber.actions").clear_log_statements() end, desc = "Timber: clear log statements (buffer)" },
      { "<leader>lt", function() require("timber.actions").toggle_comment_log_statements() end, desc = "Timber: toggle-comment log statements" },
      { "<leader>lf", function() require("timber.actions").search_log_statements() end, desc = "Timber: search log statements" },
    },
    opts = {
      default_keymaps_enabled = false, -- drop gl*; use the <leader>l group only
      -- House-style log templates. The %watcher_marker_start/_end pair is what
      -- the neotest watcher greps for (it embeds the 🪵 log_marker, which also
      -- lets <leader>lc/<leader>lt find+clear these lines). The captured runtime
      -- value is whatever prints BETWEEN the two markers:
      --   PHP: error_log → stderr (visible to phpunit; the GAF Logger facade is
      --        NOT used here — it routes to logstash and the watcher can't see it).
      --        var_export($x, true) matches GAF's scalar/array dump convention.
      --   TS:  console.log (eslint `no-console` allows `log` in the webapp).
      log_templates = {
        default = {
          php        = [[error_log("%log_target = %watcher_marker_start" . var_export(%log_target, true) . "%watcher_marker_end");]],
          typescript = [[console.log("%log_target =", "%watcher_marker_start", %log_target, "%watcher_marker_end")]],
          javascript = [[console.log("%log_target =", "%watcher_marker_start", %log_target, "%watcher_marker_end")]],
          tsx        = [[console.log("%log_target =", "%watcher_marker_start", %log_target, "%watcher_marker_end")]],
          jsx        = [[console.log("%log_target =", "%watcher_marker_start", %log_target, "%watcher_marker_end")]],
        },
      },
      -- neotest integration: timber tags inserted logs with a marker, watches
      -- neotest output for that marker, and surfaces the captured runtime values
      -- inline + in the summary panel (<leader>ls).
      log_watcher = {
        enabled = true,
        sources = {
          neotest = { type = "neotest", name = "Neotest" },
        },
      },
    },
    config = function(_, opts)
      require("timber").setup(opts)
    end,
  },
}
