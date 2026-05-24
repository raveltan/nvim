# editor-vim-repeat
> Makes `.` repeat plugin-defined mappings, not just native edits.

**Repo:** https://github.com/tpope/vim-repeat
**Local spec:** lua/plugins/editor.lua:483
**Tags:** repeat, vimscript, tpope, foundation

## Scope

Vim's `.` only repeats edits performed by built-in commands. `vim-repeat` exposes a `repeat#set()` API that plugins call after their mapping fires; subsequent `.` then replays that plugin mapping instead of the last raw keystrokes. Required by mini.surround, yanky.nvim, vim-abolish coercions, and many others.

## Install spec

```lua
{ "tpope/vim-repeat", event = "VeryLazy" }
```

Loaded on `VeryLazy` because plugins that depend on it (mini.surround, yanky) are themselves lazy on `VeryLazy`/`BufReadPost` — repeat just needs to be available before the first `.` press.

## Common customizations

None. `vim-repeat` has no options, commands, or settings. It's a pure-vimscript shim that plugins detect via `exists("*repeat#set")`.

WebFetch https://raw.githubusercontent.com/tpope/vim-repeat/HEAD/README.markdown if uncertain.

## Our config

Zero configuration. Presence alone enables:

- `gsa` / `gsd` / `gsr` (mini.surround) repeat with `.`
- `cr*` coercions from vim-abolish repeat with `.`
- yanky.nvim's `p`/`P` after-paste cycling repeats with `.`

## Keymaps

None. Activation is via the `repeat#set()` API call from other plugins.

## Links

- Plugin repo: https://github.com/tpope/vim-repeat
- API: `:help repeat#set()`

## Notes

- If a plugin mapping doesn't repeat, check whether that plugin actually calls `repeat#set` — some don't. Filing an issue upstream is the only fix.
- Loading order matters: vim-repeat must be sourced before the first plugin mapping fires. `VeryLazy` is early enough because plugin mappings are also lazy.
- Companion to [[editor-vim-abolish]] (case coercions repeat via this) and mini.surround.
