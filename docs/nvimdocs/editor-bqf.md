# editor-bqf

> ⚠️ **REMOVED** — plugin is no longer in this config (quickfix preview now plain + quicker.nvim). Doc kept for history.
> Better quickfix: live preview window, fzf filter, syntax-highlighted entries.

**Repo:** https://github.com/kevinhwang91/nvim-bqf
**Local spec:** lua/plugins/editor.lua:197-202
**Tags:** quickfix, preview, fzf, lsp, editor

## Scope

`nvim-bqf` upgrades the builtin quickfix and loclist windows with a treesitter-rendered preview, a magic prompt to filter entries with fzf, and shortcuts to convert between quickfix lists, signs, and locations. It pairs naturally with LSP references/diagnostics, grep results, and `:cdo`.

## Install spec

```lua
{
  "kevinhwang91/nvim-bqf",
  ft = "qf",
  opts = {
    preview = { winblend = 0 },
  },
}
```

Loaded only when a quickfix buffer (`ft = "qf"`) is opened — zero startup cost.

## Common customizations

- `auto_enable` *(bool, true)* — auto-attach bqf to every quickfix window.
- `auto_resize_height` *(bool, false)* — resize qf height to entry count.
- `preview.auto_preview` *(bool, true)* — open preview window automatically.
- `preview.border` *(string, "rounded")* — `rounded` | `single` | `double` | `solid` | `shadow` | `none`.
- `preview.show_title` *(bool, true)* — show file path in preview title.
- `preview.show_scroll_bar` *(bool, true)*.
- `preview.delay_syntax` *(integer, 50)* — ms before treesitter highlights preview.
- `preview.win_height` *(integer, 15)* — max preview height.
- `preview.win_vheight` *(integer, 15)* — preview height when qf is on a vertical split.
- `preview.winblend` *(integer, 12)* — preview transparency. We set `0` for full opacity.
- `preview.wrap` *(bool, false)*.
- `preview.buf_label` *(bool, true)* — show buffer label in preview.
- `preview.should_preview_cb` *(function)* — return false to skip preview for a given bufnr/qwinid.
- `func_map` *(table)* — remap any of bqf's qf-window actions (`open`, `openc`, `drop`, `tabdrop`, `split`, `vsplit`, `tab`, `prevfile`, `nextfile`, `prevhist`, `nexthist`, `lastleave`, `stoggleup`, `stoggledown`, `stogglevm`, `stogglebuf`, `sclear`, `pscrollup`, `pscrolldown`, `pscrollorig`, `ptoggleitem`, `ptoggleauto`, `ptogglemode`, `filter`, `filterr`, `fzffilter`).
- `filter.fzf.action_for` *(table)* — `ctrl-t`/`ctrl-x`/`ctrl-v`/`ctrl-q`/`ctrl-c` map to tab/split/vsplit/sign/closeall.
- `filter.fzf.extra_opts` *(string[])* — extra fzf cli args.

WebFetch https://raw.githubusercontent.com/kevinhwang91/nvim-bqf/HEAD/README.md for the full default-keymap table.

## Our config

Just `preview = { winblend = 0 }` — keep preview fully opaque against the colourscheme; everything else is upstream defaults including auto_enable + auto_preview.

## Keymaps

All defaults (active inside a quickfix window):

| Key | Action | Desc |
|-----|--------|------|
| `p` | toggle preview auto-mode | |
| `P` | toggle preview window | |
| `<C-f>` / `<C-b>` | scroll preview down/up | |
| `zf` | open fzf filter prompt | |
| `zn` / `zN` | new qf list from selected entries (negated) | |
| `zr` | restore original qf entries | |
| `zz` / `zs` | toggle sign on entry / clear signs | |
| `<` / `>` | older / newer qf list | |
| `<Tab>` / `<S-Tab>` | toggle sign + next/prev | |
| `<CR>` | open entry | |
| `o` / `O` | open in split / vsplit | |
| `t` | open in tab | |

Inside the `zf` fzf prompt: `<C-t>` tab, `<C-x>` split, `<C-v>` vsplit, `<C-q>` add to signs, `<C-c>` close.

## Links

- Plugin repo: https://github.com/kevinhwang91/nvim-bqf

## Notes

- Works in tandem with `quicker.nvim` (also in editor.lua): bqf gives preview + fzf filter, quicker gives editable qf and prettier rendering. They coexist because bqf attaches via `BufWinEnter qf` and quicker via its own setup.
- fzf filter requires the `fzf` binary on PATH; without it `zf` falls back to a quieter `:cfilter`-style prompt.
- Preview uses real treesitter highlighting on the source buffer, so it respects your global TS config.
