# dap-virtual-text
> Inline variable values as virtual text while stopped at a breakpoint.

**Repo:** https://github.com/theHamsta/nvim-dap-virtual-text
**Local spec:** lua/plugins/dap.lua:28-52
**Tags:** dap virtual-text inline-values treesitter

## Scope
Uses treesitter to find variable identifiers, then annotates them with current DAP values via extmarks. Greatly reduces the need to mouse over or expand the scopes pane.

## Install spec
```lua
{
  "theHamsta/nvim-dap-virtual-text",
  opts = {
    enabled = true,
    enable_commands = true,
    clear_on_continue = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = true,
    show_stop_reason = true,
    commented = false,
    only_first_definition = false,
    all_references = true,
    virt_text_pos = "eol",
    all_frames = false,
    virt_lines = false,
    display_callback = function(variable, _buf, _stackframe, _node, options)
      local val = variable.value or ""
      if options.virt_text_pos == "inline" then return " = " .. val end
      if #val > 80 then val = val:sub(1, 80) .. "…" end
      return "  ▸ " .. variable.name .. " = " .. val
    end,
  },
}
```

## Common customizations
- `enabled` *(bool, `true`)* — master switch.
- `enable_commands` *(bool, `true`)* — register `:DapVirtualText*` user commands.
- `highlight_changed_variables` *(bool, `true`)* — distinct hl group for values that mutated since previous stop.
- `highlight_new_as_changed` *(bool, `false`)* — treat newly-in-scope vars as changed.
- `show_stop_reason` *(bool, `true`)* — render exception/stop reason as virtual text at the stopped line.
- `commented` *(bool, `false`)* — prefix value with the language's comment syntax (helps when copying).
- `only_first_definition` *(bool, `true`)* — annotate only first occurrence per scope.
- `all_references` *(bool, `false`)* — annotate every reference; combine with `only_first_definition=false` for max coverage.
- `clear_on_continue` *(bool, `false`)* — wipe extmarks when execution resumes.
- `virt_text_pos` *(string, default `"inline"` on nvim 0.10+, else `"eol"`)* — `"eol"` puts annotation at end of line, `"inline"` inserts mid-line.
- `all_frames` *(bool, `false`)* — annotate every frame in the call stack, not just the current.
- `virt_lines` *(bool, `false`)* — render as a new virtual line below source (experimental).
- `display_callback` *(function)* — `(variable, buf, stackframe, node, options) → string|nil` for custom formatting.

## Our config
- `clear_on_continue = true` — keep the view clean between stops; stale values hurt more than absent ones.
- `only_first_definition = false` + `all_references = true` — annotate every reference; we read code top-down and want values at every use.
- `highlight_new_as_changed = true` — treat first-frame-in vars as changed (highlighted on entry).
- `virt_text_pos = "eol"` — inline mode shifts code horizontally and breaks alignment in long PHP lines.
- Custom `display_callback`: truncates values >80 chars with `…`, prefixes with `  ▸ ` and `name = ` so multi-var lines stay scannable.

## Keymaps
None — relies on automatic refresh on DAP events. `:DapVirtualTextEnable/Disable/Toggle` available via `enable_commands`.

## Links
- README: https://github.com/theHamsta/nvim-dap-virtual-text
- Related: [dap-nvim-dap](dap-nvim-dap.md)

## Notes
- Requires nvim-treesitter parsers for the language being debugged. Missing parser = no virtual text.
- Custom highlight groups `NvimDapVirtualText`, `NvimDapVirtualTextChanged`, `NvimDapVirtualTextError`, `NvimDapVirtualTextInfo` are set in our `config` block to override the default palette.
