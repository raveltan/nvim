# lsp-lightbulb
> Sign-column bulb when a code action is available at the cursor.

**Repo:** https://github.com/kosayoda/nvim-lightbulb
**Local spec:** lua/plugins/lsp.lua
**Tags:** lsp, code-action, signs, ui

## Scope

Polls `textDocument/codeAction` on `CursorHold`/`CursorHoldI` and drops a bulb in the sign column
when the server offers an action. Fills the one gap in the code-action workflow:
[lsp-actions-preview](lsp-actions-preview.md) shows actions beautifully but only *after* you ask
for them, so there was previously no signal that an action existed at all.

## Install spec

```lua
{
  "kosayoda/nvim-lightbulb",
  event = "LspAttach",
  opts = {
    autocmd = { enabled = true },
    sign = { enabled = true, text = "󰌵", hl = "LightBulbSign" },
    virtual_text = { enabled = false },
    ignore = { ft = { "markdown", "text", "gitcommit" } },
  },
  config = function(_, opts)
    require("nvim-lightbulb").setup(opts)
    vim.api.nvim_set_hl(0, "LightBulbSign", { fg = "#e3c78a" }) -- moonfly yellow
  end,
}
```

## Common customizations

- `sign` *(table)* — `{ enabled, text, lens_text, hl }`; sign-column bulb.
- `virtual_text` *(table)* — `{ enabled, text, hl, hl_mode }`; end-of-line bulb.
- `float` *(table)* — bulb in a floating window.
- `number` / `line` *(table)* — highlight the line number or whole line instead.
- `status_text` *(table)* — expose a string for statusline components.
- `autocmd` *(table, `enabled = false`)* — `{ enabled, updatetime, events, pattern }`. Must be
  enabled or nothing updates automatically.
- `ignore` *(table)* — `{ clients, ft, actions_without_kind }`.
- `filter` *(fn)* — drop specific actions before counting.

## Our config

- `sign` only. `virtual_text` is **off** because tiny-inline-diagnostic owns end-of-line virtual
  text and a code action is usually available exactly where a diagnostic is — see
  [ui-tiny-inline-diagnostic](ui-tiny-inline-diagnostic.md).
- `autocmd.enabled = true`, inheriting `updatetime = 500` from
  [config-options](config-options.md).
- `ignore.ft` skips prose buffers where an action is either always or never present.
- `LightBulbSign` is set to moonfly yellow `#e3c78a` explicitly so the bulb is not confused with
  a diagnostic sign.

## Gutter budget

This plugin is the reason `'signcolumn'` is **`yes:2`** and not `yes`. Four things now compete
for the gutter: gitsigns hunk bars, marks.nvim marks, diagnostic severity icons, and this bulb.
At width 1, the highest-priority sign silently hides the others — the bulb would eat a
diagnostic. The gutter is rendered through comfy-line-numbers' `'statuscolumn'`
(`%=%s%=%{...}`), whose `%s` honours the configured `signcolumn` width.

## Keymaps

| Key | Mode | Action | Desc |
|---|---|---|---|
| — | — | — | None. The bulb is passive; trigger actions with `<leader>ca` ([lsp-actions-preview](lsp-actions-preview.md)). |

## Links

- README: https://github.com/kosayoda/nvim-lightbulb/blob/master/README.md
- Related: [lsp-actions-preview](lsp-actions-preview.md), [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md), [git-gitsigns](git-gitsigns.md), [editor-marks](editor-marks.md)

## Notes

- If the gutter ever looks crowded, prefer dropping a *sign* consumer over reverting to
  `signcolumn = "yes"` — sign loss is silent and hard to notice.
- The bulb respects `updatetime`; a much lower `updatetime` makes it flicker on cursor motion.
