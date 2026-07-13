# dap-nvim-dap-ruby
> Ruby debugger (rdbg / debug.gem) configurations for nvim-dap.

**Repo:** https://github.com/suketa/nvim-dap-ruby
**Local spec:** lua/plugins/dap.lua:95
**Tags:** dap ruby rdbg rspec rails

## Scope
Registers `dap.adapters.ruby` (rdbg, ruby's built-in debug gem) and a handful of `dap.configurations.ruby` entries (current file, RSpec, Rails). Single `setup()` call — no options.

## Install spec
```lua
{
  "suketa/nvim-dap-ruby",
  config = function() require("dap-ruby").setup() end,
}
```

## Common customizations
None — the plugin has no public options. Behavior is fixed:
- Adapter: launches `rdbg --open --port ${port}` (or attaches to an existing socket).
- Configurations injected: "current file", "run rspec current_file", "run rspec", "debug rails", "attach rdbg socket".

To tweak, overwrite entries in `dap.configurations.ruby` *after* calling `setup()`.

## Our config
Bare `setup()` — we use the default rspec/rails entries as-is. No custom Ruby configs in our spec.

## Keymaps
None plugin-specific; standard `<leader>dc/di/do/dO` apply.

## Links
- README: https://github.com/suketa/nvim-dap-ruby
- Related: [dap-nvim-dap](dap-nvim-dap.md)

## Debugging a Rails server

**One-shot: `:RailsDebug` / `<leader>dR`** (`lua/util/rails_debug.lua`) — starts
`bundle exec rdbg -n --open --port 38698 -c -- bin/rails server` from the
nearest `bin/rails` root, mirrors server output into the dap-repl, and attaches
automatically when rdbg announces its socket. Run again to re-attach after a
detach. `:RailsDebugStop` disconnects and kills the server.

Manual variant (external terminal — server survives nvim):

```sh
bundle exec rdbg -n --open --port 38698 -c -- bin/rails server
# or: RUBY_DEBUG_OPEN=true RUBY_DEBUG_PORT=38698 bin/rails server
```

Then `<leader>dc` → pick **"attach existing (port 38698)"**. `localfs = true` is
already set in the plugin's base config, so breakpoints map to local paths.
Detach leaves the server running; re-attach any time.

## Notes
- Requires `gem install debug` on the host ruby (or in your project Gemfile). The `rdbg` binary must be on `$PATH` at debug time.
- Not installed via mason — it's pure Lua plus shelling to system rdbg.
