# prod-hardtime
> Nudges you off hjkl spam and arrow keys toward real motions (`w`, `f`, `}`, etc.).

**Repo:** https://github.com/m4xshen/hardtime.nvim
**Local spec:** lua/plugins/productivity.lua:77-92
**Tags:** habit motion hint keystroke

## Scope
Watches your normal-mode keys. If you mash the same motion >N times in a row (default 3, ours is 4) it either blocks the key or prints a hint suggesting a better motion. Arrow keys can be disabled outright. Filetype exclusion list keeps it out of pickers, file trees, REPLs, etc.

## Install spec
```lua
{
  "m4xshen/hardtime.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = { ... },
}
```

## Common customizations
- `max_count` *(number, 3)* — repeats of the same key before it's restricted.
- `max_time` *(number, 1000)* — ms window for counting repeats.
- `restriction_mode` *("block"|"hint", "block")* — `"block"` swallows the key; `"hint"` lets it through with a message.
- `disable_mouse` *(bool, true)* — block mouse in normal mode.
- `hint` *(bool, true)* — show suggestion messages.
- `notification` *(bool, true)* — use vim.notify; off = `:echo`.
- `disabled_filetypes` *(table)* — filetypes where hardtime is fully off. Default includes `qf`, `netrw`, `NvimTree`, `lazy`, `mason`, `oil`, `help`.
- `disabled_keys` *(table, { ["<Up>"]=..., ["<Down>"]=..., ... })* — per-mode key disablement.
- `restricted_keys` *(table)* — keys subject to repeat-counting (h/j/k/l/+/-/`<Up>`/`<Down>`/`<Left>`/`<Right>`).
- `hints` *(table)* — custom regex→message rules. e.g. `{ ["k%^"] = { message = function() return "Use gg" end, length = 2 } }`.
- `callback` *(function)* — custom hook on restriction.

See https://github.com/m4xshen/hardtime.nvim/blob/main/doc/hardtime.txt.

## Our config
- `max_count = 4` — slightly more lenient than default 3.
- `disable_mouse = false` — mouse stays on.
- `restriction_mode = "hint"` — keys still work, just nag.
- `disabled_filetypes` includes our full picker/tree/debug surface:
  `qf, netrw, NvimTree, lazy, mason, oil, help, trouble, TelescopePrompt, snacks_picker_input, snacks_picker_list, dbee, dbui, dap-repl, dapui_scopes, dapui_breakpoints, dapui_stacks, dapui_watches, dapui_console, aerial`.

## Keymaps
None defined. Use `:Hardtime toggle|enable|disable|report` to control at runtime.

## Links
- README: https://github.com/m4xshen/hardtime.nvim
- Help: `:help hardtime`
- Related: [editor-flash](editor-flash.md), [editor-mini-ai](editor-mini-ai.md)

## Notes
- Lazy-loaded on `VeryLazy` so it doesn't slow startup.
- `nui.nvim` dep is for the notification surface.
- `:Hardtime report` prints repeat stats — useful to see your worst offenders.
- If you're stuck mid-keystroke and need it off briefly: `:Hardtime disable`, run your motion, `:Hardtime enable`.
