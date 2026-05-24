# ruby-vim-projectionist
> Project-aware `:A` alternate + `:E*` navigation driven by configurable projections.

**Repo:** https://github.com/tpope/vim-projectionist
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/ror.lua:212-285
**Tags:** ruby, rails, navigation, projections, tpope

## Scope
Generic projection engine — given a glob → metadata map, exposes `:A` (alternate), `:Emodel`, `:Econtroller`, `:Eview`, `:Espec`, `:Ehelper`, `:Ejob`, `:Eservice`, `:Epolicy`, `:Eserializer`, `:Edecorator`, `:Eform`, and templated `:cnew` for each `type`. We register one heuristic keyed on the presence of `config/environment.rb` and `Gemfile`, so projections only activate inside Rails projects. Lazy-loads on `ruby`/`eruby`.

## Install spec
```lua
{
  "tpope/vim-projectionist",
  ft = { "ruby", "eruby" },
  init = function()
    vim.g.projectionist_heuristics = {
      ["config/environment.rb&Gemfile"] = { -- projections table },
    }
  end,
}
```

## Common customizations
- `vim.g.projectionist_heuristics` — table-of-tables: outer key is an `&`-joined heuristic of marker files, inner keys are glob patterns mapping to `{ type, alternate, template, ... }`.
- WebFetch https://raw.githubusercontent.com/tpope/vim-projectionist/HEAD/README.markdown for the full projection schema (`make`, `dispatch`, `start`, `console`, etc.).

## Our config
Heuristic activates on `config/environment.rb&Gemfile`. The full projection map:

| Glob | type | alternate | template |
|---|---|---|---|
| `app/controllers/*_controller.rb` | controller | `spec/controllers/{}_controller_spec.rb` | `class {camelcase\|capitalize\|colons}Controller < ApplicationController / end` |
| `spec/controllers/*_controller_spec.rb` | spec | `app/controllers/{}_controller.rb` | — |
| `app/models/*.rb` | model | `spec/models/{}_spec.rb` | `class {camelcase\|capitalize\|colons} < ApplicationRecord / end` |
| `spec/models/*_spec.rb` | spec | `app/models/{}.rb` | — |
| `app/views/*` | view | — | — |
| `app/helpers/*_helper.rb` | helper | `spec/helpers/{}_helper_spec.rb` | — |
| `app/mailers/*.rb` | mailer | `spec/mailers/{}_spec.rb` | — |
| `app/jobs/*.rb` | job | `spec/jobs/{}_spec.rb` | — |
| `app/services/*.rb` | service | `spec/services/{}_spec.rb` | — |
| `app/policies/*_policy.rb` | policy | `spec/policies/{}_policy_spec.rb` | — |
| `app/serializers/*_serializer.rb` | serializer | `spec/serializers/{}_serializer_spec.rb` | — |
| `app/decorators/*_decorator.rb` | decorator | `spec/decorators/{}_decorator_spec.rb` | — |
| `app/forms/*_form.rb` | form | `spec/forms/{}_form_spec.rb` | — |
| `spec/factories/*.rb` | factory | — | — |
| `db/migrate/*.rb` | migration | — | — |
| `config/routes.rb` | routes | — | — |
| `config/database.yml` | database | — | — |
| `db/schema.rb` | schema | — | — |
| `Gemfile` | gemfile | — | — |
| `Rakefile` | rakefile | — | — |

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| _(none mapped)_ | — | — | Use `:A` / `:E*` ex-commands |

Useful commands:
- `:A` — toggle alternate (model ↔ spec etc.)
- `:Emodel user`, `:Econtroller users`, `:Eservice billing`, `:Epolicy post` — type-typed jumps
- `:Emodel user|w` — create with template if file missing

## Links
- Plugin README: https://github.com/tpope/vim-projectionist
- Projection schema: `:help projectionist`
- Companion: [[ruby-vim-rails]] (`:R*` commands), [[ruby-ror]] (Rails commands palette)

## Notes
- We host non-stock Rails patterns here: `services/`, `policies/`, `serializers/`, `decorators/`, `forms/`. Add new conventions to the heuristic in `lua/plugins/ror.lua` rather than to a separate file.
- Templates use tpope's transform stack: `{camelcase|capitalize|colons}` turns `admin/user_role` → `Admin::UserRole`.
- For many-target picks (controller → many views) prefer `other.nvim` (`<leader>oo`); projectionist's `:A` is for fast single-alternate hops.
