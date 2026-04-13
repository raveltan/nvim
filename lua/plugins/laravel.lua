return {
  -- Laravel development toolkit (artisan, routes, models, tinker)
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
    },
    cond = function()
      return vim.fn.filereadable(vim.fn.getcwd() .. "/artisan") == 1
    end,
    ft = { "php", "blade" },
    keys = {
      { "<leader>ll", function() Laravel.pickers.laravel() end, desc = "Laravel picker" },
      { "<leader>la", function() Laravel.pickers.artisan() end, desc = "Artisan" },
      { "<leader>lr", function() Laravel.pickers.routes() end, desc = "Routes" },
      { "<leader>lR", function() Laravel.pickers.related() end, desc = "Related files" },
      { "<leader>lm", function() Laravel.pickers.make() end, desc = "Make (scaffold)" },
      { "<leader>lc", function() Laravel.pickers.commands() end, desc = "Commands" },
      { "<leader>lo", function() Laravel.pickers.resources() end, desc = "Resources" },
      { "<leader>lv", function() Laravel.commands.run("view:finder") end, desc = "View finder" },
      { "<leader>lp", function() Laravel.commands.run("command_center") end, desc = "Command center" },
    },
    opts = {
      features = {
        pickers = {
          enable = true,
          provider = "snacks",
        },
      },
      extensions = {
        diagnostic = { enable = false },
      },
    },
  },

  -- Blade file navigation + Livewire component navigation
  {
    "ricardoramirezr/blade-nav.nvim",
    ft = { "blade", "php" },
    opts = {
      close_tag_on_complete = true,
    },
  },
}
