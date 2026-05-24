# editor-dropbar
> Winbar breadcrumbs of LSP/treesitter symbol path with keyboard-navigable picker.

**Repo:** https://github.com/Bekaboo/dropbar.nvim
**Local spec:** lua/plugins/editor.lua:557-579
**Tags:** editor winbar breadcrumb navigation lsp treesitter picker

## Scope
Renders a clickable winbar showing `path / to / file > Class > method` based on LSP document symbols (falls back to treesitter). The `<leader>;` pick opens a fzf-driven menu to jump within the current breadcrumb. We disable the bar in floats, diff windows, and a long list of utility buftypes (oil, qf, dap-ui, neotest, snacks-picker, neogit commit) so it does not clutter sidebars.

## Install spec
```lua
{
  "Bekaboo/dropbar.nvim",
  dependencies = { "nvim-telescope/telescope-fzf-native.nvim" },
  event = "BufReadPost",
  opts = {
    bar = {
      enable = function(buf, win)
        if not vim.api.nvim_buf_is_valid(buf) then return false end
        if not vim.api.nvim_win_is_valid(win) then return false end
        if vim.fn.win_gettype(win) ~= "" then return false end
        if vim.wo[win].diff then return false end
        local ft = vim.bo[buf].filetype
        local skip = { oil = true, qf = true, help = true, lazy = true,
                       mason = true, trouble = true,
                       snacks_picker_list = true,
                       ["dap-repl"] = true,
                       dapui_scopes = true, dapui_breakpoints = true,
                       dapui_stacks = true, dapui_watches = true,
                       dapui_console = true,
                       ["neotest-summary"] = true,
                       ["neotest-output"] = true,
                       ["neotest-output-panel"] = true,
                       gitcommit = true,
                       NeogitCommitMessage = true }
        if skip[ft] then return false end
        return vim.bo[buf].buftype == ""
      end,
    },
  },
  keys = { ... },
}
```

## Common customizations
- `bar.enable` *(bool | function(buf, win))* — gate for showing the winbar. We use a function; upstream default enables for normal listed buffers.
- `bar.update_events.win` / `bar.update_events.buf` / `bar.update_events.global` *(string[])* — autocmd events that trigger a refresh.
- `bar.sources` *(table[])* — symbol providers. Defaults pick from `path`, `treesitter`, `lsp`, `markdown` in priority order. Override to reorder or disable.
- `bar.padding`, `bar.pick.pivots` *(string)* — pick-mode hint letters; defaults `"abcdefghijklmnopqrstuvwxyz"`.
- `bar.truncate` *(bool, default true)* — ellipsise long paths.
- `menu.preview` *(bool)* — show a code preview in the picker menu.
- `menu.win_configs` — per-level floating-window geometry.
- `icons.kinds.symbols` *(table)* — LSP SymbolKind → glyph map.
- `sources.path.relative_to` *(function)* — root for the path-source. Default is `vim.fn.getcwd()`.
- `sources.lsp.valid_symbols` *(string[])* — whitelist of SymbolKind names. Useful to drop `Variable`/`Field` noise.
- `require("dropbar.api").pick()` / `goto_context_start()` / `select_next_context()` — the three API entry points we bind.

## Our config
The only override is `bar.enable`. It is a strict allowlist — buffer/window must be valid, win must be a real window (`win_gettype(win) == ""`), not a diff view, with empty `buftype`, and filetype not in the skip set.

**Skip set rationale:**
- `oil`, `qf`, `help`, `lazy`, `mason`, `trouble` — utility/list views with no symbol structure.
- `snacks_picker_list` — picker list; winbar collides with the picker prompt.
- `dap-repl`, `dapui_*` — dap-ui panels are fixed-size, no room for a winbar.
- `neotest-summary` / `output` / `output-panel` — neotest panels.
- `gitcommit`, `NeogitCommitMessage` — commit message buffers are short-lived; a path-breadcrumb is pure noise.

All other defaults (sources, icons, picker) are stock.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>;` | n | `require("dropbar.api").pick()` | Pick across breadcrumb |
| `[;` | n | `require("dropbar.api").goto_context_start()` | Jump to start of current context |
| `];` | n | `require("dropbar.api").select_next_context()` | Select next sibling context |

Mouse: clicking a segment in the winbar opens its dropdown directly (handled by the plugin).

## Links
- README: https://github.com/Bekaboo/dropbar.nvim
- Help: `:help dropbar.nvim`
- Related: LSP setup in `lua/plugins/lsp.lua`; picker UI shares the snacks family.

## Notes
- `telescope-fzf-native` is listed as a dependency for the picker fuzzy backend; lazy.nvim will build it on first install (`make`).
- The custom `enable` function runs on every winbar refresh — keep it cheap. The current implementation is O(1) (table lookup + a few flag checks).
- If a new dap-ui or test panel filetype is added later, append it to the `skip` table to suppress its winbar.
- For diff splits the winbar is intentionally off; the diff highlight already telegraphs context.
