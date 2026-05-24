# editor-illuminate
> Highlight every occurrence of the word/symbol under the cursor; `]]`/`[[` to cycle.

**Repo:** https://github.com/RRethy/vim-illuminate
**Local spec:** lua/plugins/editor.lua:490-504
**Tags:** highlight, lsp, treesitter, references, editor

## Scope

`vim-illuminate` paints other instances of the symbol under your cursor. It tries multiple providers in order — LSP `documentHighlight` first (semantically correct, distinguishes locals from globals), then treesitter (syntactic), then a regex fallback. A buffer-attached debouncer keeps it cheap. `]]`/`[[` jump between highlighted occurrences without an LSP roundtrip.

## Install spec

```lua
{
  "RRethy/vim-illuminate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("illuminate").configure({
      providers = { "lsp", "treesitter" },
      delay = 400,
      large_file_cutoff = 1500,
      large_file_overrides = { providers = {} },
      filetypes_denylist = { "oil", "trouble", "lazy", "mason", "help", "noice", "checkhealth", "snacks_picker_list" },
      min_count_to_highlight = 2,
    })
    vim.keymap.set("n", "]]", function() require("illuminate").goto_next_reference(false) end)
    vim.keymap.set("n", "[[", function() require("illuminate").goto_prev_reference(false) end)
  end,
}
```

Loaded on `BufReadPost`/`BufNewFile` so highlights show up before you start moving the cursor.

## Common customizations

- `providers` *(string[], {"lsp","treesitter","regex"})* — provider order. First one that returns matches wins. We drop `regex` to avoid noisy highlights inside strings/comments.
- `delay` *(integer, 100)* — ms debounce after `CursorMoved`. We use `400` so quick scans don't flicker.
- `filetype_overrides` *(table, {})* — per-ft tweaks: `{ python = { providers = { "lsp" } } }`.
- `filetypes_denylist` *(string[])* — turn off entirely in these filetypes.
- `filetypes_allowlist` *(string[], {})* — if set, only these are highlighted.
- `modes_denylist` *(string[], {})* — disable in specific modes (e.g. `{ "i" }`).
- `modes_allowlist` *(string[], {})*.
- `providers_regex_syntax_denylist` / `_allowlist` *(string[])* — when using the regex provider, skip/keep these syntax groups (`Comment`, `String`, etc.).
- `under_cursor` *(bool, true)* — also highlight the word the cursor is on. `false` skips it so the active symbol isn't visually re-painted.
- `large_file_cutoff` *(integer, nil)* — buffer line count above which `large_file_overrides` apply.
- `large_file_overrides` *(table, nil)* — config slice swapped in for huge buffers. We set `providers = {}` (disable highlighting; jumps still work via cached state — actually they don't, see notes).
- `min_count_to_highlight` *(integer, 1)* — need at least N matches before any are painted.
- `should_enable(bufnr) -> bool` — custom gate.
- `case_insensitive_regex` *(bool, false)* — for the regex provider.

WebFetch https://raw.githubusercontent.com/RRethy/vim-illuminate/HEAD/README.md if option names drift.

## Our config

- `providers = { "lsp", "treesitter" }` — no regex provider; avoids matching plain words inside strings.
- `delay = 400` — slower-than-default debounce keeps `CursorMoved` cheap when scrolling.
- `large_file_cutoff = 1500` with `large_file_overrides = { providers = {} }` — buffers ≥1500 lines disable highlighting.
- `filetypes_denylist = { "oil", "trouble", "lazy", "mason", "help", "noice", "checkhealth", "snacks_picker_list" }` — UI / plugin buffers where occurrences are meaningless.
- `min_count_to_highlight = 2` — don't bother for a single isolated identifier.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `]]` | n | `illuminate.goto_next_reference(false)` | Next occurrence of symbol (no wrap) |
| `[[` | n | `illuminate.goto_prev_reference(false)` | Prev occurrence of symbol (no wrap) |

The argument `false` disables wrap-around at file ends.

## Links

- Plugin repo: https://github.com/RRethy/vim-illuminate
- LSP documentHighlight spec: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_documentHighlight

## Notes

- `]]`/`[[` are vim's builtin "next/prev section" motions. We replace them globally — losing that is fine for most filetypes, but in C/markdown/man you'll want `:Illuminate` only or rebind. (Currently we accept the loss.)
- `]r`/`[r` from [[editor-refjump]] use the LSP cross-file references list — use those for jumping across files; use `]]`/`[[` for cycling visible occurrences in the current buffer.
- Large-file override disables providers entirely; on a 1500+ line file you'll get neither highlights nor working `]]`/`[[`. Lower `delay` instead if you'd rather keep them.
- The hlgroups (`IlluminatedWordText`, `IlluminatedWordRead`, `IlluminatedWordWrite`) are styled by your colourscheme; override with `:hi` if too subtle.
