# ruby-vim-rails
> tpope's classic Rails plugin: :R*/:E* navigation commands, partial/factory `gf`, Rails syntax tweaks.

**Repo:** https://github.com/tpope/vim-rails
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/ror.lua:175-178
**Tags:** ruby, rails, navigation, tpope

## Scope
Adds Rails-aware vim commands: `:Rcontroller`, `:Rmodel`, `:Rview`, `:Rmigration`, `:Rspec`, `:Rextract`, `:Rinvert`, and the `:A`/`:AS`/`:AV`/`:AT` alternate-file family. Makes `gf` follow partial renders (`render "user"` → `app/views/users/_user.html.erb`), factories, fixtures, and `require` paths. Adds Rails-specific syntax highlighting (`belongs_to`, `validates`, etc.). Lazy-loads on `ruby`/`eruby` filetypes.

## Install spec
```lua
{
  "tpope/vim-rails",
  ft = { "ruby", "eruby" },
}
```

## Common customizations
- No setup function — works out of the box once loaded inside a Rails project (detected by `config/environment.rb`).
- `g:rails_projections` / `g:rails_buffer_processing` to add custom file types. We instead use vim-projectionist for projection overrides (see [[ruby-vim-projectionist]]) since vim-rails projections are deprecated in favour of projectionist's.
- WebFetch https://raw.githubusercontent.com/tpope/vim-rails/HEAD/README.markdown if uncertain about a specific command.

## Our config
No config. Pure lazy-load on filetype.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| _(none mapped)_ | — | — | We rely on `:E*`/`:R*` ex-commands directly |

Useful commands (typed, not mapped):
- `:Econtroller users` — edit `app/controllers/users_controller.rb`
- `:Emodel user` — edit `app/models/user.rb`
- `:Eview users/show` — edit `app/views/users/show.html.erb`
- `:Espec user` — edit `spec/models/user_spec.rb`
- `:Emigration create_users` — edit matching migration
- `:A` — jump to alternate (model ↔ spec, controller ↔ spec)
- `:R` — like `:A` but "related" (e.g. controller → view)
- `:Rextract partial_name` — extract visual selection into a partial
- `:Rinvert` — invert a migration `change` block

## Links
- Plugin README: https://github.com/tpope/vim-rails
- Commands list: `:help rails-commands`
- Companion: [[ruby-vim-projectionist]] (projections), [[ruby-ror]] (modern Rails tooling)

## Notes
- vim-rails and vim-projectionist coexist. vim-rails owns `:R*`/`:E*` + Rails-aware `gf`; projectionist owns `:A` alternate routing via our heuristic in `lua/plugins/ror.lua`.
- For richer many-target alternate picks (e.g. controller → multiple views), prefer `other.nvim`'s `<leader>oo`.
