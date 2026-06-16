-- redash.nvim — run ad-hoc SQL through Redash's HTTP API, results in a float.
-- Local checkout while developing; swap `dir` for "rtanjaya/redash.nvim" once
-- published. URL via $REDASH_URL or vim.g.redash_url; API key from
-- ~/brainskey.txt (kept out of this repo).
--
-- GAF-gated: Redash is a Freelancer service, so register the plugin (and its
-- csvview dep) only under the GAF profile. vim.g.gaf is set in init.lua before
-- lazy reads this spec. The matching which-key group is gated in editor.lua.
if not vim.g.gaf then
  return {}
end

return {
  {
    dir = vim.fn.expand("~/redash.nvim"),
    name = "redash.nvim",
    cmd = { "Redash", "RedashRun", "RedashSource", "RedashTables", "RedashCancel" },
    ft = { "sql" }, -- load on sql buffers so the <leader>rr run key is wired
    -- Dedicated <leader>r group (separate from the <leader>D dadbod/DB group):
    keys = {
      { "<leader>ro", "<cmd>Redash<cr>",       desc = "Redash: open scratch" },
      { "<leader>rt", "<cmd>RedashTables<cr>", desc = "Redash: browse schema" },
      { "<leader>rs", "<cmd>RedashSource<cr>", desc = "Redash: data source" },
      { "<leader>rk", "<cmd>RedashCancel<cr>", desc = "Redash: cancel query" },
    },
    dependencies = {
      -- Renders the result grid (ui.style="csvview"): colored, aligned columns.
      -- keymaps enable column navigation (delimiter-aware, skips quoted commas):
      --   <Tab>/<S-Tab> next/prev column, if/af field text-objects.
      {
        "hat0uma/csvview.nvim",
        opts = {
          view = { display_mode = "border" },
          keymaps = {
            jump_next_field_start = { "<Tab>", mode = { "n", "v" } },
            jump_prev_field_start = { "<S-Tab>", mode = { "n", "v" } },
            textobject_field_inner = { "if", mode = { "o", "x" } },
            textobject_field_outer = { "af", mode = { "o", "x" } },
          },
        },
      },
    },
    opts = {
      api_key_file = "~/brainskey.txt",
      -- url comes from $REDASH_URL (set in ~/.zshrc) — kept out of this public
      -- repo since it's an internal hostname.
      data_source_id = 6, -- FLN-Redshift (Regular Access); :RedashSource to switch
      run_key = "<leader>rr", -- run buffer/selection (buffer-local in sql buffers)
      ui = { style = "csvview" }, -- "float" | "split" | "csvview"
    },
  },
}
