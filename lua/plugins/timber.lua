-- Print/log-injection debugging. Treesitter-aware log insertion for the
-- variable under the cursor (or visual selection).
--
-- Insert-and-clean only — NO runtime capture/summary. timber can only capture
-- values from a neotest result file or a tailed local file; our debugging runs
-- in the browser (ng serve) and on a remote devbox (HTTP), neither of which is
-- a local file, so capture is dropped. Read the value wherever the output
-- normally lands (terminal / browser console / fpm log); <leader>lc wipes the
-- inserted logs. A single 🪵 (%log_marker) is kept in each template so the
-- clear/search/toggle commands can still find timber's own lines.
--
-- Keys (all under <leader>l):
--   <leader>ll  log var under cursor / visual selection, below (use every time)
--   <leader>lc  clear timber log statements (buffer)
--   <leader>lt  toggle-comment timber log statements
--   <leader>lf  search timber log statements (telescope, saved files)
return {
  {
    "Goose97/timber.nvim",
    version = "*",
    keys = {
      {
        "<leader>ll",
        function() require("timber.actions").insert_log({ position = "below" }) end,
        mode = { "n", "v" },
        desc = "Timber: log var below",
      },
      { "<leader>lc", function() require("timber.actions").clear_log_statements() end, desc = "Timber: clear log statements (buffer)" },
      { "<leader>lt", function() require("timber.actions").toggle_comment_log_statements() end, desc = "Timber: toggle-comment log statements" },
      { "<leader>lf", function() require("timber.actions").search_log_statements() end, desc = "Timber: search log statements" },
    },
    opts = {
      default_keymaps_enabled = false, -- drop gl*; use the <leader>l group only
      -- Clean, house-style templates. %log_marker = a single 🪵 so the
      -- clear/search/toggle commands can grep these lines; NO watcher markers
      -- (capture is off). PHP: error_log + var_export (GAF throwaway-debug
      -- convention). TS: console.log (eslint allows `log`; prints objects
      -- expanded in the browser console).
      log_templates = {
        default = {
          php        = [[error_log("%log_marker %log_target = " . var_export(%log_target, true));]],
          typescript = [[console.log("%log_marker %log_target", %log_target)]],
          javascript = [[console.log("%log_marker %log_target", %log_target)]],
          tsx        = [[console.log("%log_marker %log_target", %log_target)]],
          jsx        = [[console.log("%log_marker %log_target", %log_target)]],
        },
      },
    },
    config = function(_, opts)
      require("timber").setup(opts)
    end,
  },
}
