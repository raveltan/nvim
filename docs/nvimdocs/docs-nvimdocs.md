# docs-nvimdocs
> Meta: how the Neovim plugin reference docs in this repo are organised and browsed.

**Repo:** (this config) https://github.com/rtanjaya (local: ~/.config/nvim)
**Local spec:** docs/nvimdocs/ (this directory)
**Tags:** docs meta convention picker snacks

## Scope
This is not a plugin — it is the convention for the per-plugin markdown reference files that live in `docs/nvimdocs/`. Each plugin spec in `lua/plugins/` has (or will have) a matching `<category>-<slug>.md` here. The files are plain Markdown, browsable from Neovim via the snacks picker bindings below.

## Install spec
```lua
-- No install. This is a docs convention, not a plugin.
-- The picker keymaps live with the rest of the snacks config in lua/plugins/snacks.lua.
```

## Common customizations
- **File location** — `docs/nvimdocs/` relative to `$MYVIMRC`'s directory. Resolve with `vim.fn.stdpath("config") .. "/docs/nvimdocs"` if you script it.
- **Naming** — `<category>-<slug>.md`, lowercase, hyphen-separated. Slug usually matches the upstream repo's short name (e.g. `nvim-dap` → `dap-nvim-dap.md`, `markview.nvim` → `markview.md` when category is implied).
- **Categories in use**: `dap`, `test`, `lsp`, `cmp`, `ts`, `snacks`, `docs`, `editor`, `ui`, `git`, `nav`, `ruby`, `rust`, `flutter`, `format`, `prod`, `workflow`, `gaf`, `util`, `config`, `ftplugin`, `coverage`, `emmet`.
- **Front-matter** — none; the first `#` heading is the slug.
- **Cross-links** — use `[label](slug.md)` for sibling files; relative paths only.

## Our config
Each doc file follows this fixed skeleton (kept under ~150 lines so it fits a single screen-page):

```
# <slug>
> one-line summary

**Repo:** url
**Local spec:** path:lines
**Tags:** space-separated tags

## Scope
2-3 sentences on what the plugin does and what we customise.

## Install spec
```lua ... ```

## Common customizations
- `opt` *(type, default)* — desc. Only documented options actually exist upstream.

## Our config
What we overrode and why.

## Keymaps
| Key | Mode | Action | Desc |

## Links
- README
- Related [slug](slug.md)

## Notes
Footguns, version pins, gotchas.
```

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>kn` | n | `Snacks.picker.files({ cwd = docs/nvimdocs })` | Pick a doc file |
| `<leader>kN` | n | `Snacks.picker.grep({ cwd = docs/nvimdocs })` | Live grep all docs |
| `<leader>kN` | x | grep visual selection | Grep selection across docs |

Bindings live next to the other `<leader>k…` doc bindings (`ko`/`kj`/`ks`/`kS` for devdocs). The `<leader>k` prefix is the "knowledge / kb" namespace in this config.

## Links
- Related: [docs-devdocs](docs-devdocs.md) — offline devdocs.io browser (different docset, same prefix).
- Markdown rendering inside Neovim: was [markview](markview.md) (removed).

## Notes
- Keep each file under 150 lines. If a plugin's notes grow past that, split out the GAF-specific or workflow-specific bits into their own `gaf-…` / `workflow-…` file and cross-link.
- "No invented options" — every option in a `## Common customizations` section must exist upstream. WebFetch the plugin README when uncertain rather than guessing.
- "Local spec" line numbers drift; treat them as a hint, not a contract. The slug under `lua/plugins/` is the source of truth.
- Categories are descriptive, not enforced. Add new ones (e.g. `ai-`, `term-`) by simply using them; this file is the registry.
