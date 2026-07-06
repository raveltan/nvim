# editor-which-key
> Popup hint window that documents leader-prefixed keymap groups.

**Repo:** https://github.com/folke/which-key.nvim
**Local spec:** lua/plugins/editor.lua:269
**Tags:** keymap, ui, discovery, help

## Scope

`which-key.nvim` watches partial keymap input and, after a short delay, opens a floating popup listing every continuation of that prefix. It powers keymap discovery for our leader-driven menu (find/git/buffer/code/debug/etc.) and renders both group labels declared in its `spec` and individual mappings registered elsewhere via `desc`.

## Install spec

```lua
{
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = { { "<leader>f", group = "find/files" }, ... },
  },
}
```

Lazy-loaded on `VeryLazy` so it never blocks startup. Group labels live entirely in `opts.spec`; individual keys are picked up automatically from each plugin's `keys = {}` entry via the `desc` field.

## Common customizations

- `preset` *(string, "classic")* — overall layout (`classic` | `modern` | `helix`).
- `delay` *(integer|fun, 200)* — ms before popup appears.
- `spec` *(table[])* — group/key declarations in the new v3 array format.
- `win.border` *(string, "none")* — popup border style.
- `win.padding` *(integer[], {1,2})* — `{vertical, horizontal}` inner padding.
- `layout.width` *(table, {min=20})* — column width clamp.
- `icons.mappings` *(bool, true)* — show keymap icons.
- `triggers` *(table[])* — which keys/modes open the popup. We rely on defaults.
- `plugins.marks` / `plugins.registers` *(bool, true)* — built-in pickers for `'`/`` ` ``/`"`/`<C-r>`.

WebFetch https://raw.githubusercontent.com/folke/which-key.nvim/HEAD/README.md if uncertain.

## Our config

All customisation is in `opts.spec`. Registered group prefixes:

| Prefix | Label |
|--------|-------|
| `<leader>f` | find/files |
| `<leader>s` | search |
| `<leader>g` | git |
| `<leader>gh` | hunks |
| `<leader>b` | buffer |
| `<leader>q` | quit |
| `<leader>t` | todo/test |
| `<leader>u` | ui |
| `<leader>ud` | duck |
| `<leader>x` | diagnostics |
| `<leader>c` | code |
| `<leader>cs` | swap |
| `<leader>cv` | case convert |
| `<leader>d` | debug |
| `<leader>h` | harpoon |
| `<leader>n` | obsidian |
| `<leader>o` | overseer |
| `<leader>r` | rails |
| `<leader>S` | snippets |
| `<leader>a` | ai/claude |
| `<leader>D` | database |
| `<leader>X` | xdebug profile |
| `<leader>w` | window |
| `g` | goto |
| `gs` | surround |

Plus individual desc overrides: `<leader>udd` Hatch duck, `<leader>udk` Cook one duck, `<leader>uda` Hatch fast duck, `<leader>udK` Cook all ducks, `<leader>;` Dropbar pick (h=parent l=child i=fuzzy q=close).

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>` | n,x | open popup | Trigger which-key after default delay |
| `<C-d>` / `<C-u>` | n (in popup) | scroll down/up | Built-in popup navigation |

No explicit `keys = {}`; activation is automatic on prefix idle.

## Links

- Plugin repo: https://github.com/folke/which-key.nvim
- v3 spec format: https://github.com/folke/which-key.nvim?tab=readme-ov-file#%EF%B8%8F-mappings

## Notes

- Groups are inert containers — they only render a label in the popup. The actual `<leader>nf` etc. are bound by the respective plugin specs (obsidian, snacks.pick, gitsigns, ...).
- `<leader>n` group label is `obsidian` because the entire `n` namespace is owned by [[editor-obsidian]].
- `<leader>t` is shared with [[editor-checkmate]] todo commands and neotest; group label intentionally says "todo/test".
