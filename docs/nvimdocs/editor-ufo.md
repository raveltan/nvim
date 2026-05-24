# editor-ufo
> Smarter folding backed by treesitter and indent providers, with peek preview.

**Repo:** https://github.com/kevinhwang91/nvim-ufo
**Local spec:** lua/plugins/editor.lua:7-20
**Tags:** folding, treesitter, ui

## Scope

`nvim-ufo` replaces Neovim's built-in `foldmethod` with a provider-driven model. Each buffer asks one or more providers ("treesitter", "indent", "lsp", "marker") for fold ranges; UFO then renders fold marks with virtual text showing line counts. It also supplies a peek window that previews folded contents without opening them.

## Install spec

```lua
{
  "kevinhwang91/nvim-ufo",
  dependencies = { "kevinhwang91/promise-async" },
  event = "BufReadPost",
  opts = {
    provider_selector = function()
      return { "treesitter", "indent" }
    end,
  },
  keys = { { "zR", ... }, { "zM", ... }, { "zp", ... } },
}
```

Loaded on `BufReadPost` so the first opened file initialises folds eagerly. `promise-async` is the async runtime UFO requires.

## Common customizations

- `provider_selector` *(fun(bufnr, ft, buftype) -> string[]|nil)* — list of providers to query per buffer; nil falls back to default LSP. We force `{"treesitter","indent"}` so it works without an LSP.
- `open_fold_hl_timeout` *(integer, 400)* — ms to flash the line when opening a fold.
- `close_fold_kinds_for_ft` *(table<string,string[]>)* — fold kinds auto-closed on open per filetype (LSP provider only).
- `fold_virt_text_handler` *(function)* — custom virtual-text renderer for folded lines.
- `preview.win_config` *(table)* — peek window border/winhighlight/maxheight.
- `preview.mappings` *(table)* — keys active inside the peek window.
- `enable_get_fold_virt_text` *(bool, false)* — pass virt-text from the source line into the handler.

WebFetch https://raw.githubusercontent.com/kevinhwang91/nvim-ufo/HEAD/README.md if uncertain.

## Our config

Minimal: only `provider_selector` is overridden to `{"treesitter","indent"}`. This means:

- Buffers with a treesitter parser get language-aware folds (functions, classes, blocks).
- Buffers without a parser fall back to indent-based folds.
- LSP-provided folds are intentionally bypassed — they often differ across servers and conflict with treesitter ranges.

UFO mandates `foldlevel=99`, `foldlevelstart=99`, `foldenable=true` on the Neovim side; those globals are set in the options module (not this spec).

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `zR` | n | `require("ufo").openAllFolds()` | Open all folds |
| `zM` | n | `require("ufo").closeAllFolds()` | Close all folds |
| `zp` | n | `require("ufo").peekFoldedLinesUnderCursor()` | Peek fold |

Native `za`/`zo`/`zc`/`zj`/`zk` still work — UFO only overrides the high-level open/close-all commands.

## Links

- Plugin repo: https://github.com/kevinhwang91/nvim-ufo
- Required settings: https://github.com/kevinhwang91/nvim-ufo#minimal-configuration

## Notes

- The peek window inherits cursor position — moving inside it scrolls the preview; pressing `<CR>` jumps into the folded region.
- If folds disappear after a `:edit`, the buffer's `foldmethod` likely reverted; UFO re-attaches on `BufReadPost`, not `BufEnter`.
- Treesitter provider requires the parser to be installed (see [[ts-nvim-treesitter]]).
