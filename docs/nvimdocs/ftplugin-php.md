# ftplugin-php
> Per-buffer PHP overrides: `$$ -> $this->` insert-mode abbreviation.

**Local spec:** after/ftplugin/php.lua:1-9
**Tags:** php, ftplugin, gaf, intelephense

## Scope

`after/ftplugin/php.lua` runs for every PHP buffer after the default ftplugin. It currently does one thing: maps `$$` in insert mode to expand into `$this->` so the most common method/property dereference is one keystroke shorter.

## File contents

```lua
vim.keymap.set("i", "$$", function()
  local col = vim.fn.col(".") - 1
  local before = vim.api.nvim_get_current_line():sub(1, col)
  if before:match("[%w_$]$") then
    return "$$"
  end
  return "$this->"
end, { buffer = true, expr = true, desc = "PHP: $$ -> $this->" })
```

## Behaviour

- `expr = true` — the mapping returns the string to insert.
- Looks at the character immediately before the cursor.
- If it's a word character, underscore, or `$`, returns literal `$$` (lets you type `$$x`, `_$$`, or `foo$$` without surprise expansion).
- Otherwise returns `$this->`.
- `buffer = true` — scoped to the current PHP buffer only; not a global mapping.

## Why no other PHP overrides

### Rename uses native LSP, not inc-rename

intelephense returns rename edits with the leading `$` sigil included in the new name (e.g. renaming `$foo` to `bar` emits `$bar` then `$$bar` on subsequent uses). `inc-rename.nvim` previews edits incrementally and trips over the sigil, producing double-`$` corruption.

The fix lives in the global LSP rename keymap (see [[gaf-lsp]] and [[lsp-nvim-lspconfig]]): when `vim.bo.filetype == "php"`, the rename keymap dispatches to `vim.lsp.buf.rename()` (native) instead of `:IncRename`. No buffer-local override needed here.

### Indent

Indent settings come from the runtime ftplugin (`$VIMRUNTIME/ftplugin/php.vim`) and our global `tabstop` / `shiftwidth` defaults. We do not override per-buffer.

### Formatting

PHP formatting (PHP-CS-Fixer / `phpcbf`) is handled by `conform.nvim` keyed on `filetype = "php"`, not by this ftplugin.

## GAF integration

- The `$$ -> $this->` mapping is most useful inside GAF Phoenix Handlers/Repositories where almost every line dereferences an injected dep (`$this->repository->...`).
- Snippet pack [[snippets-dir]] (`fl-handler`, `fl-repo`, etc.) uses the same `$this->` pattern.
- LSP rename for intelephense is gated on `vim.g.gaf` in the same module that wires intelephense itself — see [[gaf-lsp]].

## Links

- intelephense rename sigil bug context: `memory/nvim_php_rename.md`
- inc-rename.nvim: https://github.com/smjonas/inc-rename.nvim
- intelephense: https://intelephense.com/

## Notes

- The guard `[%w_$]$` lets you still type `$$` literally when needed — e.g. inside a heredoc or a regex.
- If you ever want to disable this for a single buffer, `:iunmap <buffer> $$`.
- Any future PHP-only key bindings (e.g. PHPUnit test runner) belong here, gated on `vim.g.gaf` if GAF-specific.
