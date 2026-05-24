# lsp-lazydev
> Loads Neovim Lua API types into `lua_ls` on demand — for Neovim config development.

**Repo:** https://github.com/folke/lazydev.nvim
**Local spec:** lua/plugins/lsp.lua:260-268
**Tags:** lua, lsp, lua_ls, neovim-api, types

## Scope

`lazydev` adds the Neovim runtime, plugin source trees, and selected third-party libraries to `lua_ls`'s `workspace.library` only when the buffer references them. Result: hover/goto-def for `vim.api.*` / `vim.uv.*` / plugin modules works in `~/.config/nvim/**/*.lua` without slowing startup or paying the full-library memory cost in unrelated Lua projects.

## Install spec
```lua
{
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    library = {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  },
}
```

Lazy-loaded on `ft = "lua"`. `lua_ls` is installed (and `vim.lsp.config()`-registered) elsewhere; lazydev does not configure the server itself, it pushes additional library paths into the running client.

## Common customizations
- `library` *(table[])* — entries are `{ path = "...", words = { "lua%-pattern" }, mods = { "module" } }`. Path is loaded when any of `words` matches the buffer text or any of `mods` is `require()`'d.
- `enabled` *(function(root_dir) → bool, defaults to enable in Neovim config paths)* — gate on project.
- `runtime` *(string, `vim.env.VIMRUNTIME`)* — Neovim runtime path.
- `integrations.lspconfig` *(boolean, `true`)* — autowire `lua_ls` settings.
- `integrations.cmp` / `integrations.coq` *(boolean, `true`)* — completion source for `require()` paths.

(See https://github.com/folke/lazydev.nvim#%EF%B8%8F-configuration.)

## Our config

- `library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } }` — pulls in libuv type stubs only when the buffer mentions `vim.uv` (timers, fs, jobs).
- Plugin source trees are auto-detected by lazydev's default rules; no manual `library` entries needed.

## Keymaps

None — works passively through `lua_ls`. Use `K` / `grn` / `grr` etc. as usual.

## Links
- README: https://github.com/folke/lazydev.nvim
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md)

## Notes

`lua_ls` itself is **not** in `mason-lspconfig`'s `ensure_installed`. It is expected to be installed manually via `:MasonInstall lua-language-server`, or it can be added to the list. lazydev assumes a running `lua_ls` client and is a no-op otherwise.
