# docs-devdocs
> Offline programming documentation browser sourcing devdocs.io archives.

**Repo:** https://github.com/maskudo/devdocs.nvim
**Local spec:** lua/plugins/docs.lua:3
**Tags:** docs devdocs reference offline markdown snacks-picker

## Scope
Downloads documentation bundles from devdocs.io, converts HTML to Markdown via pandoc, and opens them as plain buffers. Our spec rewires the open/jump/grep UX onto `snacks.picker`, adds a custom markdown link follower, and strips problematic inline SVGs so `image.nvim` does not choke on devdocs CSS variables.

## Install spec
```lua
{
  "maskudo/devdocs.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "DevDocs", "DevDocsOpen", "DevDocsJump", "DevDocsGrep",
          "DevDocsGrepAll", "DevDocsGrepVisual", "DevDocsGrepVisualAll" },
  keys = { ... },
  opts = { ensure_installed = { ... } },
  config = function(_, opts) ... end,
}
```

## Common customizations
- `ensure_installed` *(string[])* — devdocs slugs auto-installed on startup. Slugs with versions use `~`, e.g. `ruby~4.0`, `lua~5.1`.
- `:DevDocs install` / `fetch` / `delete` — upstream commands for the index registry.
- The plugin exposes `require("devdocs").GetInstalledDocs()` and `GetDocDir(slug)`; both are used by our snacks integration.
- `require("devdocs.constants").DOCS_DIR` — root of converted markdown files (typically `~/.local/share/nvim/devdocs/docs`).
- `require("devdocs.docs").ConvertHtmlToMarkdown(html, out, cb)` — internal pandoc wrapper; we monkey-patch it to strip SVG data URIs.

## Our config
**Ensured slugs:** ruby~4.0, rails~8.1, javascript, typescript, typescript~5.1, node, php, html, css, http, lua~5.1, tailwindcss, react, angular~20, markdown, nginx, sqlite, bash, git, docker, redis, rxjs, rust, sass, minitest, playwright, python~3.12.

**SVG strip preprocessor.** We override `devdocs.docs.ConvertHtmlToMarkdown` to delete `<img ... data:image/svg+xml ...>` tags before pandoc runs. DevDocs SVGs use CSS vars like `var(--primary-contrast)` that ImageMagick cannot resolve, which made `image.nvim` spam render errors and stall the UI on every cursor move.

**`follow_link` (gf / `<CR>` on devdocs buffers).** Parses three forms under the cursor:
1. Markdown `[text](target)` — matched by column, then routed to `open_target`.
2. Raw HTML `<a href="...">...</a>` — PHP docs are emitted as raw HTML; we still want clickable links.
3. Bare autolinks `<https://...>` — opened with `vim.ui.open`.

`open_target` handles `http(s)://` and `mailto:` via `vim.ui.open`, in-file anchors via `jump_anchor` (slugifies headings the same way pandoc does), and relative paths by trying `dir/path`, `dir/path.md`, `dir/path/index.md` in order. Falls back to `gf` if nothing resolves.

**Snacks picker wiring.** A `BufEnter` autocmd on `DOCS_DIR/*` records `last_doc` and installs the `gf`/`<CR>` binding. Custom commands:

| Command | Behaviour |
|---|---|
| `DevDocsOpen` | `pick_doc` → `pick_file_in_doc` (always prompt for slug) |
| `DevDocsJump` | Same as Open but reuses `last_doc` if set |
| `DevDocsGrep` | Live grep in `last_doc` (or prompt) |
| `DevDocsGrepAll` | Live grep across the whole `DOCS_DIR` |
| `DevDocsGrepVisual` | Grep visual selection in `last_doc` |
| `DevDocsGrepVisualAll` | Grep visual selection across all docs |

All pickers `confirm = "edit"` — docs replace the current buffer.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>ko` | n | `:DevDocsOpen` | Pick doc → file |
| `<leader>kj` | n | `:DevDocsJump` | Jump file in last doc |
| `<leader>ks` | n | `:DevDocsGrep` | Grep in last doc |
| `<leader>kS` | n | `:DevDocsGrepAll` | Grep all installed |
| `<leader>ks` | x | `:DevDocsGrepVisual` | Grep selection in last doc |
| `<leader>kS` | x | `:DevDocsGrepVisualAll` | Grep selection all docs |
| `<leader>ki` | n | `:DevDocs install` | Install a doc |
| `<leader>kf` | n | `:DevDocs fetch` | Fetch index |
| `<leader>kd` | n | `:DevDocs delete` | Delete installed doc |
| `gf` / `<CR>` | n | `follow_link` | Buffer-local on devdocs files |

## Links
- README: https://github.com/maskudo/devdocs.nvim
- Upstream index: https://devdocs.io/
- Related: [docs-nvimdocs](docs-nvimdocs.md) — our companion plugin docs system.

## Notes
- `last_doc` is process-local; first invocation always prompts.
- The SVG strip only matches `<img>` tags whose `src` starts with `data:image/svg+xml`; external SVG references are untouched.
- `jump_anchor` strips a leading `pdf-` prefix because PHP-on-devdocs anchors carry it.
- Pandoc is invoked by the upstream plugin; we do not configure it directly.
