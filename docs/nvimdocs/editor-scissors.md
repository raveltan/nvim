# editor-scissors
> Create and edit VSCode-format snippets from inside Neovim.

**Repo:** https://github.com/chrisgrieser/nvim-scissors
**Local spec:** lua/plugins/editor.lua:244
**Tags:** snippets, luasnip, vscode, friendly-snippets, editor

## Scope

`nvim-scissors` adds two interactive commands: pick a snippet to edit, or capture the current selection as a new snippet. It writes VSCode-style JSON snippet files (the `friendly-snippets` format) that LuaSnip and blink consume. See [[snippets-dir]] for our custom snippet layout.

## Install spec

```lua
{
  "chrisgrieser/nvim-scissors",
  dependencies = { "rafamadriz/friendly-snippets" },
  keys = {
    { "<leader>Se", function() require("scissors").editSnippet() end },
    { "<leader>Sa", function() require("scissors").addNewSnippet() end, mode = { "n", "x" } },
  },
  opts = {
    snippetDir = vim.fn.stdpath("config") .. "/snippets",
  },
}
```

Pulls `friendly-snippets` so the picker can browse community snippets too. Lazy-loaded by keymap.

## Common customizations

- `snippetDir` *(string, `~/.local/share/nvim/scissors`)* — root for snippet JSON files. Should match a path on LuaSnip's loader list.
- `editSnippetPopup.height` *(float, 0.4)* — popup window height as a screen fraction.
- `editSnippetPopup.width` *(float, 0.6)* — popup width.
- `editSnippetPopup.border` *(string, "rounded")* — `single` | `double` | `rounded` | `solid` | `none`.
- `editSnippetPopup.keymaps.cancel` *(string, "q")*.
- `editSnippetPopup.keymaps.saveChanges` *(string, "<CR>")*.
- `editSnippetPopup.keymaps.goBackToSearch` *(string, "<BS>")*.
- `editSnippetPopup.keymaps.deleteSnippet` *(string, "<C-BS>")*.
- `editSnippetPopup.keymaps.openInFile` *(string, "<C-o>")*.
- `editSnippetPopup.keymaps.insertNextPlaceholder` *(string, "<C-p>")*.
- `jsonFormatter` *(string, "none")* — `none` | `yq` | `jq`. Pretty-prints saved JSON if your shell has the tool.
- `snippetSelection.picker` *(string, "auto")* — `auto` picks telescope > snacks > vim.ui.select.
- `backdrop.enabled` *(bool, true)* — dim the rest of the screen during popup.

WebFetch https://raw.githubusercontent.com/chrisgrieser/nvim-scissors/HEAD/README.md if option set drifts.

## Our config

Just `snippetDir = stdpath("config") .. "/snippets"`. Everything else is upstream defaults. See [[snippets-dir]] for the directory layout, `package.json`, and per-filetype JSON files.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>Se` | n | `scissors.editSnippet()` | Pick + edit existing snippet |
| `<leader>Sa` | n,x | `scissors.addNewSnippet()` | Capture selection as new snippet |

Inside the edit popup (defaults): `<CR>` save, `q` cancel, `<BS>` back to picker, `<C-BS>` delete, `<C-o>` jump to file, `<C-p>` insert next placeholder marker.

## Links

- Plugin repo: https://github.com/chrisgrieser/nvim-scissors
- VSCode snippet format: https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
- Cross-ref: [[snippets-dir]] — the on-disk snippet directory we point at.

## Notes

- The `<leader>S` prefix is registered as group "snippets" in which-key.
- `addNewSnippet()` in visual mode pre-fills the body with your selection; in normal mode it starts from an empty body.
- If you change `snippetDir`, also update LuaSnip's `vscode_loader.lazy_load({ paths = ... })` so the snippets actually load at runtime.
- `friendly-snippets` is only listed to make the picker browse upstream packs; we don't load them globally in LuaSnip.
