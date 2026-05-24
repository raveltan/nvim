# ui-mini-icons
> Lightweight icon provider; lazy-loaded and registered as a `nvim-web-devicons` shim so legacy consumers work without the heavier plugin.

**Repo:** https://github.com/echasnovski/mini.icons
**Local spec:** lua/plugins/ui.lua:29-38
**Tags:** icons, devicons, ui

## Scope
Provides filetype/extension/file/directory/lsp/os glyphs for statusline, file explorer, completion, etc. Mocks `nvim-web-devicons` via `package.preload` so any plugin that `require`s `"nvim-web-devicons"` transparently gets mini.icons' glyphs without pulling in the older devicons plugin.

## Install spec
```lua
{
  "echasnovski/mini.icons",
  lazy = true,
  config = true,
  init = function()
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}
```

## Common customizations
Passed to `require("mini.icons").setup(config)`:

- `style` *(string, `"glyph"`)* — `"glyph"` for Nerd Font icons, `"ascii"` for plain-ASCII fallback.
- `default` *(table, `{}`)* — fallback `{ glyph, hl }` per category (`default`, `directory`, `extension`, `file`, `filetype`, `lsp`, `os`).
- `directory` *(table, `{}`)* — overrides per directory name, e.g. `[".git"] = { glyph = "", hl = "MiniIconsOrange" }`.
- `extension` *(table, `{}`)* — overrides per file extension.
- `file` *(table, `{}`)* — overrides per exact filename.
- `filetype` *(table, `{}`)* — overrides per `&filetype` value.
- `lsp` *(table, `{}`)* — overrides per LSP `CompletionItemKind`.
- `os` *(table, `{}`)* — overrides per OS identifier (e.g. `"linux"`, `"macos"`).
- `use_file_extension` *(fn, `function() return true end`)* — return false to skip extension lookup for a given `(ext, file)` pair.

## Our config
- `config = true` — calls `require("mini.icons").setup()` with empty config (all defaults; glyph style).
- `lazy = true` — only loads when something requires it. Most loads happen via the devicons shim during lualine/neo-tree startup.
- `init` (runs at startup) installs the `nvim-web-devicons` mock via `package.preload`. The closure isn't invoked until something `require`s `"nvim-web-devicons"`; at that point mini.icons loads and `mock_nvim_web_devicons()` populates `package.loaded["nvim-web-devicons"]` with a compatible API.

## Keymaps
None.

## Links
- README: https://github.com/echasnovski/mini.icons/blob/main/README.md
- Help: https://github.com/echasnovski/mini.icons/blob/main/doc/mini-icons.txt

## Notes
- The shim returns `package.loaded[...]` rather than the mock's return value directly — that's the documented pattern because `mock_nvim_web_devicons()` mutates the loaded table.
- Used as a `dependencies` of lualine (see ui-lualine.md) to guarantee icons resolve before the statusline first paints.
- No explicit `event` — relies on first-`require` to load. If you ever see un-iconned UI on startup, force `event = "VeryLazy"` or list as a dependency.
