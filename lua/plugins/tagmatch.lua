-- Treesitter tag matching: `%` jump + `i%`/`a%` text objects across html, xml, JSX/TSX,
-- Angular (incl. inline templates), Vue, Svelte, eruby, php, markdown, ...
-- Local plugin: ~/.config/nvim/tagmatch.nvim (see its README).
return {
  {
    dir = vim.fn.stdpath("config") .. "/tagmatch.nvim",
    name = "tagmatch",
    dependencies = { "nvim-treesitter/nvim-treesitter", "andymass/vim-matchup" },
    ft = {
      "html", "xml", "xhtml", "htmlangular", "vue", "svelte", "handlebars",
      "htmldjango", "heex", "eruby", "php", "markdown", "javascript",
      "javascriptreact", "jsx", "typescript", "typescriptreact", "tsx", "astro",
    },
    opts = {},
  },
}
