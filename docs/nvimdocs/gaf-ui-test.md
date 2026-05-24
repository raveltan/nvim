# gaf-ui-test
> Overseer task-builder helpers for running yarn UI specs ad-hoc from the GAF webapp.

**Local spec:** lua/gaf/ui_test.lua:1-59
**Tags:** gaf overseer ui-tests yarn webapp task-builder

## Scope
Builds overseer task definitions that shell out to `yarn <ui-script>` in the resolved `webapp/` directory, passing `SPECS=<name>` env. Designed to be consumed by `overseer.register_template` calls elsewhere (e.g. `lua/gaf/overseer-templates/`) — provides a uniform `build_task` factory and `condition` predicate.

## Public API
- `M.resolve_webapp_cwd()` — returns the nearest `webapp/` dir containing a `package.json`, walking upward from cwd. Returns the cwd itself if it ends in `/webapp` and has a package.json. Nil if none found.
- `M.has_webapp()` — boolean wrapper around `resolve_webapp_cwd`.
- `M.build_task(yarn_script, extra_env)` — returns an overseer `builder` function. Given `params.spec` (falling back to current buffer's basename), produces:
  ```lua
  { cmd = { "yarn", yarn_script }, cwd = <webapp_root>, env = { SPECS = spec, ...extra_env }, components = { "default" } }
  ```
- `M.params` — overseer template `params` schema: a single `spec` string param (`SPECS`), optional, blank means current file.
- `M.condition` — `{ callback = fn }` predicate gating templates: `vim.g.gaf and has_webapp()`.

## Keymaps
None. Templates that use this module hook into overseer's `<leader>oo` / `<leader>or` flow.

## GAF integration
Whole module is GAF-only — `condition.callback` short-circuits on `vim.g.gaf`. Encodes our `yarn ui:*` script convention: a template might call `build_task("ui:main:watch", { DEVTOOLS = "true" })` to surface "Webapp UI: main (watch + devtools)" in overseer.

Difference vs `gaf.neotest-ui-tests`:
- `neotest-ui-tests` integrates with neotest result UI and runs a single spec file.
- `ui_test` builds free-form overseer tasks (watch loops, devtools, mobile, alternate projects) without bouncing through neotest.

## Links
- Related: [gaf-neotest-ui-tests](gaf-neotest-ui-tests.md), [gaf-test](gaf-test.md)

## Notes
- `params.spec` default is empty string — the builder swaps in `expand("%:t")` (basename, e.g. `foo.spec.ts`) at task-build time, not template-register time, so the current file matters.
- `extra_env` is merged AFTER `SPECS` so it can override (not that you'd want to).
- `components = { "default" }` — minimal; the consuming template usually adds `on_complete_notify`, `unique`, etc.
