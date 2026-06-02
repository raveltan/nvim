local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "gruvbox-baby", "habamax" } },
  checker = {
    enabled = false,
  },
  change_detection = {
    enabled = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        -- oil (canola) owns file exploration; netrw runtime is dead weight.
        -- `gx` uses vim.ui.open (keymaps.lua), not netrw.
        "netrwPlugin",
        -- vim-matchup supersedes the built-in matchit/matchparen. Disabling
        -- the builtins is matchup's recommended setup (avoids the runtime
        -- having to deactivate matchparen after the fact).
        "matchit",
        "matchparen",
      },
    },
  },
})
