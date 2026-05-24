# config-profile
> Tiny module that remembers the last profile-test run and re-invokes it.

**Local file:** lua/config/profile.lua
**Tags:** config, profile, neotest, runner

## Scope

`lua/config/profile.lua` is a one-slot memo for "the last profile run". Language-specific runners (TypeScript, Ruby, and the GAF PHP profile runner) call `M.remember(runner, file)` after launching a profile, and `<leader>tP` (or any other key bound to it) calls `M.run_last()` to replay the most recent one without picking a runner again.

## Highlights

- **Single shared slot** (`M._last`) — the most recent runner wins, regardless of language. This is deliberate: usually you're iterating on one file at a time, and "rerun what I just did" beats "rerun the last Ruby one specifically".
- **No imports / no side effects** — the module is pure: a state field and two functions. Anyone (a neotest adapter, an ftplugin, a keymap) can require it without worrying about load order.
- **Friendly empty state** — calling `run_last` before anything has been remembered prints `No previous profile run` via `vim.notify`, no error.

## Full listing

```lua
local M = {}

M._last = nil

function M.remember(runner, file)
  M._last = { runner = runner, file = file }
end

function M.run_last()
  local l = M._last
  if not l then
    vim.notify("No previous profile run", vim.log.levels.WARN)
    return
  end
  l.runner(l.file)
end

return M
```

## Public API

- `M.remember(runner, file)` — store a `{runner, file}` pair. `runner` is any callable that accepts `file`. Overwrites any previous entry.
- `M.run_last()` — invoke `runner(file)` for the most recently remembered pair. Warns and returns when nothing is stored.

## Links

- Related [gaf-neotest-profile](gaf-neotest-profile.md) — PHP profile runner that calls `remember`.
- Related [config-neotest-profile-ts](config-neotest-profile-ts.md) — TypeScript profile runner.
- Related [config-neotest-profile-ruby](config-neotest-profile-ruby.md) — Ruby profile runner.

## Notes

- The slot is in-memory only — it does **not** survive a Neovim restart. Persisting would need `vim.fn.stdpath("state")` + serialisation; out of scope for now.
- `runner` is stored by reference. If you re-`require` the runner module and replace its functions, the stored reference will still point at the old closure until `remember` is called again.
- Keep this module dependency-free. It's the lowest tier of the profile stack and language runners are expected to depend on it, not vice versa.
