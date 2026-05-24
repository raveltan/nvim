# ruby-ror
> Rails commands, generators, routes/schema browsers, and DB/bundle runners for Neovim.

**Repo:** https://github.com/weizheheng/ror.nvim
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/ror.lua:3-171
**Tags:** ruby, rails, telescope, runner

## Scope
Rails-aware command palette (`list_commands`), generator picker, routes/schema list views, and async runners for `db:migrate`, `db:rollback`, and `bundle install`. Lazy-loads on `ruby`/`eruby` filetypes. Pulls in telescope + fzf-native + ui-select for pickers. The same plugin spec is reused here as the host for the project's `ruby_lsp`, `sorbet`, `stimulus_ls`, and `herb_ls` LSP configs, ruby-lsp `rubyLsp.openFile` execute_command shim, and codelens autocmds.

## Install spec
```lua
{
  "weizheheng/ror.nvim",
  ft = { "ruby", "eruby" },
  dependencies = {
    "neovim/nvim-lspconfig",
    "saghen/blink.cmp",
    "nvim-telescope/telescope.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    { "nvim-telescope/telescope-ui-select.nvim" },
  },
  config = function()
    require("telescope").load_extension("fzf")
    require("telescope").load_extension("ui-select")
    require("ror").setup({})
    -- ... LSP configs (ruby_lsp, sorbet, stimulus_ls), codelens autocmds
  end,
}
```

## Common customizations
- `setup({})` — passed empty; ror.nvim defaults used. Override test runners, notification position, or coverage paths via the table. WebFetch https://raw.githubusercontent.com/weizheheng/ror.nvim/HEAD/README.md if unsure.
- Telescope extensions `fzf` + `ui-select` loaded here because ror.nvim's pickers use vim.ui.select.

## Our config
Setup is minimal — all customisation happens at the keymap layer (see below). The `config` function in this spec does more than just ror.nvim setup: it also configures `ruby_lsp` (with a custom `reuse_client` to defeat lspconfig's broken `cmd_cwd` comparison, indexing exclusions for `db/schema.rb`, and `formatter = "none"` to defer to conform.nvim), `sorbet`, `stimulus_ls`, the `rubyLsp.openFile` command shim for route→controller CodeLens links, and a debounced `BufWritePost` codelens refresh on `*.rb`/`*.erb`.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>rc` | n | `ror.commands.list_commands()` | Rails commands palette (destroy, migrate status, bundle update, sync routes, coverage) |
| `<leader>rg` | n | `ror.generators.select_generators()` | Rails generator picker |
| `<leader>rr` | n | `ror.routes.list_routes()` | List routes (telescope) |
| `<leader>rs` | n | `ror.schema.list_table_columns()` | Schema columns for current model |
| `<leader>rm` | n | `ror.runners.db_migrate.run()` | DB migrate |
| `<leader>rk` | n | `ror.runners.db_rollback.run()` | DB rollback |
| `<leader>rb` | n | `ror.runners.bundle_install.run()` | Bundle install |
| `<leader>rC` | n | `bin/rails console` in `botright split` terminal (height 15) | Rails console |
| `<leader>re` | n | `bin/rails credentials:edit` in `botright split` terminal | Edit credentials |
| `<leader>cc` | n (ruby/eruby) | `vim.lsp.codelens.run` | Run codelens under cursor |

`<leader>rC` / `<leader>re` prefer `bin/rails` (binstub) when present, fall back to `rails`.

## Links
- Plugin README: https://github.com/weizheheng/ror.nvim
- Companion: [[ruby-vim-rails]], [[ruby-vim-projectionist]], [[ruby-vim-endwise]], [[ruby-conform-rubocop]]
- Test infra: [[test-neotest]], [[test-neotest-adapters]]

## Notes
- Console/credentials open in `botright split` + `terminal` + `startinsert` — they are not ror.nvim features; they are project-local keymaps colocated here for discoverability.
- ror.nvim ships its own neotest-like test runners but we use neotest with `neotest-rspec` separately (see [[test-neotest-adapters]]).
- The `<leader>r*` prefix is dedicated to Rails; do not bind it to other tools.
