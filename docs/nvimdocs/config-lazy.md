# config-lazy
> Bootstraps lazy.nvim, imports `lua/plugins/`, disables built-ins and auto-update checks.

**Local file:** lua/config/lazy.lua
**Tags:** config, lazy, bootstrap, performance

## Scope

`lua/config/lazy.lua` clones lazy.nvim on first run, prepends it to `rtp`, then calls `require("lazy").setup` with a single spec import — `{ import = "plugins" }` — so every `lua/plugins/*.lua` file is picked up automatically. The setup also opts out of update notifications and runtime-path scanning of vendored built-ins we never use.

## Highlights

- **Bootstrap clone** is hard-pinned to `--branch=stable` and uses `--filter=blob:none` so the initial clone is quick. On failure it prints the git output and waits for a keypress before `os.exit(1)` — fatal, by design, since nothing downstream works without lazy.
- **Single spec import** — `{ import = "plugins" }` — keeps the bootstrap file tiny. Every plugin lives in its own file under `lua/plugins/` and lazy's importer auto-discovers them.
- **`install.colorscheme = { "gruvbox-baby", "habamax" }`** — the colorscheme list lazy uses while installing on first launch, before any real config has loaded. `habamax` is the always-available built-in fallback.
- **`checker.enabled = false`** — no background `git fetch` against every plugin. Updates happen manually via `:Lazy update`.
- **`change_detection.enabled = false`** — editing a plugin spec file doesn't trigger an auto-reload prompt. We restart Neovim explicitly when needed.
- **`performance.rtp.disabled_plugins`** — disables `gzip`, `tarPlugin`, `tohtml`, `tutor`, `zipPlugin`. We don't edit archives in-place and we never run `:Tutor`, so skipping their rtp scan shaves a few ms off startup.

## Full listing

```lua
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
      },
    },
  },
})
```

## Links

- Related [config-init](config-init.md)
- Plugin specs: `lua/plugins/*.lua`
- lazy.nvim: https://github.com/folke/lazy.nvim

## Notes

- New plugins: drop a file in `lua/plugins/`, no edit to this file required.
- To temporarily re-enable update checks: `:lua require("lazy").check()` instead of flipping `checker.enabled`.
- `netrwPlugin` is **not** in the disabled list — `gx` falls back to `vim.ui.open` which depends on netrw being available.
