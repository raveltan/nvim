# cmp-luasnip
> Snippet engine; loads friendly-snippets and the local `snippets/` dir.

**Repo:** https://github.com/L3MON4D3/LuaSnip
**Local spec:** lua/plugins/lsp.lua:271-288
**Tags:** snippets, completion

## Scope

LuaSnip is the snippet expansion engine behind `blink.cmp`. It parses VS Code style JSON snippet packs and Lua snippet files, manages tab-stops, and handles dynamic / choice nodes. We use it purely as a backend — expansion is triggered by accepting a snippet candidate from the blink menu, not by a standalone trigger key.

## Install spec

```lua
{
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  build = "make install_jsregexp",
  dependencies = { "rafamadriz/friendly-snippets" },
  config = function()
    local ls = require("luasnip")
    ls.config.setup({
      history = true,
      updateevents = "TextChanged",
      enable_autosnippets = false,
    })
    require("luasnip.loaders.from_vscode").lazy_load()
    require("luasnip.loaders.from_vscode").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
  end,
}
```

`make install_jsregexp` compiles a JS-regex transformer so VS Code snippets that use regex transforms work. `friendly-snippets` provides the community pack.

## Common customizations

- `history` *(bool, false)* — allow `<Tab>` to jump back into a finished snippet's tab-stops. We enable.
- `updateevents` *(string, "InsertLeave")* — when to re-evaluate dynamic nodes. We use `TextChanged` so previews update live as you type.
- `enable_autosnippets` *(bool, false)* — fire snippets whose `wordTrig`/`autoTrig` matches as you type. We leave off — all expansion goes through the blink menu.
- `region_check_events` *(string)* — when to verify the cursor is still inside the active snippet region.
- `delete_check_events` *(string)* — when to garbage-collect finished snippets.

## Our config

- VS Code loader called twice:
  1. `lazy_load()` (no args) → picks up `friendly-snippets` automatically.
  2. `lazy_load({ paths = … })` → loads `~/.config/nvim/snippets/` (see [[snippets-dir]]).
- Lua loader is NOT registered — all custom snippets live as VS Code JSON files.
- Both packs are lazy-loaded: snippets for a filetype are only parsed the first time you enter a buffer of that filetype.

## Keymaps

Jump keys come from `blink.cmp`'s default preset, not LuaSnip itself.

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<Tab>` | i, s | `snippet_forward` (via blink) | Next tab-stop |
| `<S-Tab>` | i, s | `snippet_backward` (via blink) | Previous tab-stop |
| `<CR>` | i | accept candidate | Triggers expansion when the highlighted item is a snippet |

## Links

- Plugin repo: https://github.com/L3MON4D3/LuaSnip
- friendly-snippets: https://github.com/rafamadriz/friendly-snippets
- VS Code snippet format: https://code.visualstudio.com/docs/editor/userdefinedsnippets

## Notes

- The snippets dir is exposed to LuaSnip via `snippets/package.json` (a VS Code extension manifest stub). Adding a new filetype requires editing that manifest.
- `scissors.nvim` edits/creates the same JSON files (see [[editor-scissors]]). After scissors writes a file, LuaSnip picks it up on next BufEnter for the matching filetype — no reload needed.
- Choice nodes (`${1|a,b,c|}`) work since v2.
- If a snippet fails to fire, check `:LuaSnipListAvailable` to confirm it loaded for the current filetype.
