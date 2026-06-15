# ruby-vim-rails
> tpope's Rails plugin — sole owner of Rails file navigation (`:A`/`:R`/`:E*`), partial/factory `gf`, syntax tweaks. Also the load carrier for the Ruby LSP stack.

**Repo:** https://github.com/tpope/vim-rails
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/rails.lua:6-149 (custom projections `init` at :18-83, LSP `config` at :85+)
**Tags:** ruby, rails, navigation, tpope, projections, avo, turbo, factorybot, actionpolicy, devise

## Scope
Adds Rails-aware navigation + commands, active only inside a detected Rails app (file must live under the app — detection is file-context, not cwd). Lazy-loads on `ruby`/`eruby` filetypes.

- `:A` / `:AS` / `:AV` / `:AT` — alternate file (mostly source ↔ test/spec) in window / hsplit / vsplit / tab.
- `:R` — **related** file, *context-aware*: cursor in a controller `def show` jumps to `show.html.erb` for that action. Pattern-matchers (e.g. other.nvim) can't do this.
- `:E{type}` (+ `:S`/`:V`/`:T` split variants) — open by type with tab-completion: `:Emodel user`, `:Eview users/show`, `:Econtroller users`, `:Espec user`, `:Emigration create_users`, …
- `gf` — follows partial renders (`render "user"` → `app/views/users/_user.html.erb`), factories, fixtures, route helpers, `require` paths.
- `:Rextract partial` (visual) — extract selection into a partial. `:Rinvert` — invert a migration `change` block.
- Rails syntax highlighting (`belongs_to`, `validates`, …).

**Auto-defined commands:** for any `app/{type}s/` dir containing `*_{type}.rb`, vim-rails auto-creates `:E{type}`. So `:Ejob` (app/jobs), `:Epolicy`, `:Eserializer` etc. exist even without config — our projections below just enrich them with `:A`/`:R` wiring.

## Install spec
```lua
{
  "tpope/vim-rails",
  ft = { "ruby", "eruby" },
  dependencies = { "neovim/nvim-lspconfig", "saghen/blink.cmp" },
  init = function() vim.g.rails_projections = { ... } end,  -- see below
  config = function() ... end,                              -- Ruby LSP stack
}
```

## Our config

### Custom projections (`g:rails_projections`, set in `init`)
vim-rails ships native types for model/view/controller/helper/mailer/spec/migration/etc. We add the gem + framework conventions it doesn't know about. Each entry creates `:E<command>` and (where listed) wires `:A` → spec and `:R` → model. `init` (not `config`) so `g:rails_projections` exists before the plugin processes the buffer.

| Command | Opens | `:A` → | `:R` → | For |
|---|---|---|---|---|
| `:Epolicy foo` | `app/policies/foo_policy.rb` | spec | model | **ActionPolicy** (same paths as Pundit) |
| `:Eserializer foo` | `app/serializers/foo_serializer.rb` | spec | model | AMS / blueprinter |
| `:Edecorator foo` | `app/decorators/foo_decorator.rb` | spec | model | Draper |
| `:Eform foo` | `app/forms/foo_form.rb` | spec | model | form objects |
| `:Eresource foo` | `app/avo/resources/foo.rb` | — | model | **Avo v3** admin |
| `:Eavoaction` / `:Eavofilter` | `app/avo/actions/` · `filters/` | — | — | Avo |
| `:Edashboard` / `:Ecard` | `app/avo/dashboards/` · `cards/` | — | — | Avo |
| `:Eresourcetool foo` | `app/avo/resource_tools/foo.rb` | — | `_foo.html.erb` partial | Avo |
| `:Efactory users` | `spec/factories/users.rb` | — | — | **FactoryBot** |
| `:Ejob foo` | `app/jobs/foo_job.rb` | spec | — | ActiveJob |
| `:Emailerpreview foo` | `*/mailers/previews/foo_mailer_preview.rb` | — | mailer | ActionMailer previews |
| `:Eturbostream users/create` | `app/views/users/create.turbo_stream.erb` | — | — | **Turbo** Streams |
| `:Estimulus hello` | `app/javascript/controllers/hello_controller.js` | — | — | Hotwire Stimulus |

### Stack support matrix
| Tool | Handled by | Notes |
|---|---|---|
| RSpec | native + projections (`spec/*_spec.rb`) | tests run via neotest, see [[test-neotest-adapters]] |
| ActionPolicy | `:Epolicy` projection | identical paths to Pundit |
| Devise | native `:Econtroller`/`:Eview` | `users/sessions_controller`, `app/views/devise/…` — no special config |
| Avo (v3) | resource/action/filter/dashboard/card/resourcetool projections | on **Avo 2** swap `app/avo/resources/*.rb` → `*_resource.rb` |
| Turbo | `:Eturbostream` (+ `gf`) | Frames are inline tags, no files. `:Eview` defaults to `.html.erb`, won't reach `.turbo_stream.erb` |
| FactoryBot | `:Efactory` | files pluralised; no reliable model↔factory `:A` bridge |

### LSP load carrier
The spec's `config` doubles as the Ruby LSP setup — `ruby_lsp`, `sorbet`, and `stimulus_ls` all configure here (see [[lsp-nvim-lspconfig]]). Highlights: `ruby_lsp` reuse_client patched to compare name+root_dir (avoids dup clients); formatter deferred to conform ([[ruby-conform-rubocop]]); `db/schema.rb` excluded from the generic indexer (dedup); codelens intentionally never enabled.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| _(none mapped)_ | — | — | All via `:A`/`:R`/`:E*` ex-commands |

## Tests
vim-rails' own `:Rails`/`.Runner` test running is **not** used — neotest owns Ruby via `neotest-rspec` + `neotest-minitest`. Use the `<leader>t*` family (run last `<leader>tl`, debug `<leader>tL`, summary `<leader>ts`, …). See [[test-neotest]] / [[test-neotest-adapters]] / [[ruby-debug-coverage]].

## Links
- Plugin README: https://github.com/tpope/vim-rails — Commands: `:help rails-commands`
- Projections: `:help rails-projections`, projectionist `:help projectionist`
- Companion: [[ruby-vim-endwise]], [[ruby-conform-rubocop]], [[test-neotest-adapters]], [[workflow-other]]

## Notes
- **Rails navigation was consolidated here (Jun 2026)** — the ~250-line Rails block in other.nvim ([[workflow-other]]) was deleted. vim-rails owns all Rails nav now (context-aware `:R`, completion-based `:E*`); other.nvim keeps only PHP + Angular. In the GAF (PHP/Angular) monorepo neither fired on Rails paths anyway.
- vim-rails activates only inside a real Rails app — outside one, all the above is dormant (and the projections are inert).
- Stimulus path assumed `app/javascript/controllers/`. Adjust the glob for `app/frontend/controllers/` or jsbundling/importmap layouts. Pairs with `stimulus_ls` (needs `npm i -g stimulus-language-server`) for completion + `gd` on `data-controller`/`data-action`.
- WebFetch https://raw.githubusercontent.com/tpope/vim-rails/HEAD/README.markdown if uncertain about a specific command.
