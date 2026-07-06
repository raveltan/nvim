# workflow-overseer
> Task runner: define, launch, and manage shell/build tasks from inside Neovim.

**Repo:** https://github.com/stevearc/overseer.nvim
**Local spec:** lua/plugins/workflow.lua:4
**Tags:** workflow task-runner overseer dap ui-tests gaf

## Scope
Lazy-loaded on user templates and six `<leader>o*` keys. Tasks discovered from custom user templates living in `lua/overseer/template/user/`. DAP integration enabled so debuggable tasks (e.g. jest specs) can launch via `nvim-dap`. Task list dock anchors to the bottom of the screen, 8-20 lines tall.

## Install spec
```lua
{
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerShell", "OverseerToggle", "OverseerTaskAction", "OverseerOpen", "OverseerClose" },
  opts = {
    dap = true,
    template_dirs = { "overseer.template.user" },
    task_list = { direction = "bottom", min_height = 8, max_height = { 20, 0.2 } },
  },
}
```

## Common customizations
- `dap` *(bool, true)* — wire `nvim-dap` so tasks can run under a debug adapter.
- `template_dirs` *(string[], {"overseer.template.user"})* — Lua module paths scanned for `.lua` template files. Each module returns `{ name, builder, params?, condition? }`.
- `task_list.direction` *("left"|"right"|"top"|"bottom", "left")* — dock placement for `:OverseerToggle`.
- `task_list.min_height` / `max_height` — height bounds when `direction` is `top`/`bottom`. `max_height = { 20, 0.2 }` means min(20, 20% of screen).
- `strategy` *(string|table, "terminal")* — how a running task is hosted (`terminal`, `jobstart`, `toggleterm`). Leave default unless integrating with toggleterm.
- `component_aliases.default` — what runs around every task (notify-on-fail, on-output-quickfix, etc.). See `:h overseer.Component`.

## Our config
Templates auto-discovered from `lua/overseer/template/user/`:

| File | Name | Yarn script | Extra env | Condition |
|------|------|-------------|-----------|-----------|
| `fli_provision.lua` | `fli provision (devbox)` | runs `fli provision` on devbox `rtanjaya` | — | `vim.g.gaf` |
| `ui_test_current.lua` | `ui test (current)` | `ui:main` | — | `vim.g.gaf` + webapp/ found |
| `ui_test_devtools_current.lua` | `ui test devtools (current)` | `ui:main` | `DEVTOOLS=true` | `vim.g.gaf` + webapp/ |
| `ui_test_watch_current.lua` | `ui test watch (current)` | `ui:main:watch` | — | `vim.g.gaf` + webapp/ |
| `ui_test_watch_devtools_current.lua` | `ui test watch devtools (current)` | `ui:main:watch` | `DEVTOOLS=true` | `vim.g.gaf` + webapp/ |
| `ui_test_mobile_current.lua` | `ui test mobile (current)` | `ui:main:mobile` | — | `vim.g.gaf` + webapp/ |
| `ui_test_mobile_devtools_current.lua` | `ui test mobile devtools (current)` | `ui:main:mobile` | `DEVTOOLS=true` | `vim.g.gaf` + webapp/ |
| `ui_test_mobile_watch_current.lua` | `ui test mobile watch (current)` | `ui:main:mobile:watch` | — | `vim.g.gaf` + webapp/ |
| `ui_test_mobile_watch_devtools_current.lua` | `ui test mobile watch devtools (current)` | `ui:main:mobile:watch` | `DEVTOOLS=true` | `vim.g.gaf` + webapp/ |

All UI-test templates share `lua/gaf/ui_test.lua` helpers — they accept an optional `SPECS` param (defaults to current buffer basename), `cd` into the discovered `webapp/` dir, and run `yarn <script>` with `SPECS=<spec>` plus any extra env.

## Keymaps
| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>or` | n | `:OverseerRun` | Pick a template and run |
| `<leader>oc` | n | `:OverseerShell` | Ad-hoc shell command |
| `<leader>ol` | n | task picker → `open float` | Open task output in floating window |
| `<leader>oh` | n | task picker → `open hsplit` | Open task output in horizontal split |
| `<leader>ov` | n | task picker → `open vsplit` | Open task output in vertical split |
| `<leader>od` | n | task picker → `dispose` | Dispose a task |

## GAF integration
Every user template guards with `condition.callback = function() return vim.g.gaf and ... end` — they are invisible when `GAF=1` is not set. UI-test templates additionally call `gaf.ui_test.has_webapp()` to walk up from cwd looking for a `webapp/package.json`, so they only surface in monorepos that have one. `fli provision` runs against devbox `rtanjaya` (hard-coded inside `fli`). See [[gaf-ui-test]] for the spec-pattern helper used by every `ui_test_*` template.

## Links
- README: https://github.com/stevearc/overseer.nvim
- Related: [[gaf-ui-test]], [[test-neotest]] (sister runner for unit tests)

## Notes
- `OverseerRun` lists every template whose `condition.callback` passes — fastest way to see "what can I run here".
- `params.spec` defaults to `expand("%:t")` (basename only). To run a globbed pattern, pass `*.foo.spec.ts` when prompted.
- Adding a template: drop a Lua file in `lua/overseer/template/user/` returning the standard table — no plugin reload needed for new tasks within the same session if `OverseerRun` re-scans (otherwise `:Lazy reload overseer.nvim`).
