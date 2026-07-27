# laravel-nvim
> Artisan, routes, Tinker, model introspection and Eloquent code actions.

**Repo:** https://github.com/adalessa/laravel.nvim
**Local spec:** lua/plugins/laravel.lua:20
**Tags:** laravel artisan tinker eloquent routes livewire picker snacks

## Scope
Everything that needs to *ask the running application* something: artisan commands, the route table, `make:*` generators, model schema, Tinker. Pickers are backed by `snacks.picker`. Requires a writable `vendor/` — the plugin drops a small PHP probe there to introspect the project.

## Keymaps
| Key | Action |
|---|---|
| `<leader>ll` | Master picker (everything below in one list) |
| `<leader>la` | Artisan command picker |
| `<leader>lr` | Routes picker |
| `<leader>lm` | `make:*` picker |
| `<leader>lc` | Custom commands (`user_commands`) |
| `<leader>lo` | Resources picker |
| `<leader>lt` | Code actions |
| `<leader>lu` | Artisan Hub (tabbed terminals: serve, queue, pail, vite) |
| `<leader>lp` | Command Center |
| `<leader>lh` | `artisan docs` in a popup |
| `<leader>lk` | `env:configure` — switch this project's environment |
| `<leader>lf` | View finder (jump to a view / find its usages). The README maps this to `<C-g>`, which would shadow the built-in "show file info" in every buffer of every project. |


## Virtual information
Shown inline, no keymap needed:
- **models** — connection, table, columns
- **controllers** — HTTP method, URI, middleware for the action under the cursor
- **composer.json** — installed version + an outdated marker

## Code actions (`<leader>lt`)
Generate `$fillable`, add an Eloquent relation, jump to a model's migration, scaffold a listener for an event, copy/move/delete a Livewire component.

## Tinker
`.tinker` files open a side-by-side REPL with formatted output for models, collections and query builders, plus execution time and memory.

## Our config
```lua
{
  debug_level = vim.log.levels.WARN,          -- upstream default is DEBUG: it narrates
                                              -- every introspection call through notify
  features = { pickers = { provider = "snacks" } },
  environments = { ask_on_boot = false },     -- resolved from disk instead; see below
}
```

`environments.ask_on_boot = false` because lua/artisan/init.lua already derives the environment from disk (a compose file → `sail`/`docker`, otherwise `local`) for formatting, linting and Xdebug path mappings. Override it per project with `<leader>lk`; the choice is stored under `stdpath('data')/laravel/config.json`.

## `gf` ownership
Neither plugin maps `gf` any more — lua/artisan/gf.lua does, and calls them as steps of an explicit chain. Letting blade-nav own the key was actively broken: on a miss it replays whatever global `gf` existed at setup time, and laravel.nvim's is a callback-only `expr` map whose `rhs` is nil, so **every** unresolved `gf` in a php/blade buffer — plain file paths included — raised `E5108`. See [[laravel-blade-nav]].

## Module name
This config's own Laravel code lives in `lua/artisan/`, **not** `lua/laravel/`. The config's `lua/` sits at the head of the runtimepath, so a `lua/laravel/init.lua` here shadows laravel.nvim's own entry point: the plugin silently never boots, the `Laravel` global is never created, and every keymap above errors with `attempt to index global 'Laravel' (a nil value)`. Do not rename it back.

## GAF gating
Load triggers (`ft`, `event`, `keys`) are emptied under `GAF=1` rather than using `cond`/`enabled`: lazy.nvim files a `cond = false` plugin under `spec.disabled`, so `GAF=1 :Lazy clean` would **uninstall** it — the mirror image of the trap that prunes GAF-only plugins when cleaning without the flag. Empty triggers keep the spec installed and simply never fire.

## Gotchas
- blink completion is **not** auto-registered by this plugin (its boot only calls `cmp.register_source`). The provider is wired by hand in lua/plugins/lsp.lua — see [[laravel-blade]].
- No user commands or keymaps ship with the plugin; the table above is entirely ours.
- `ripgrep` is required for `view:finder` and go-to-migration.

## See also
[[laravel-blade]] · [[laravel-blade-nav]] · [[laravel-tooling]]
