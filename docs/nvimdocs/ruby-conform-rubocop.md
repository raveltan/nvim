# ruby-conform-rubocop
> Ruby/ERB formatter wiring for conform.nvim — rubocop daemon for `.rb`, erb_format for `.erb`.

**Repo:** https://github.com/stevearc/conform.nvim (host) — RuboCop https://github.com/rubocop/rubocop
**Local spec:** /Users/rtanjaya/.config/nvim/lua/plugins/ror.lua:190-206
**Tags:** ruby, eruby, formatter, conform, rubocop

## Scope
A `conform.nvim` `opts` extension block colocated in `ror.lua` that:
1. Registers `rubocop` as the Ruby formatter and `erb_format` as the eruby formatter.
2. Overrides conform's stock `rubocop` formatter definition to use `--server` (rubocop daemon) and `--stderr` (redirect diagnostics to stderr), with `-a` autocorrect and `--fail-level fatal`.

It does not own conform's core setup — that lives in `lua/plugins/format-conform.lua` (see [[format-conform]]). The opts function uses `vim.tbl_deep_extend("force", ...)` so the override merges into whatever the base conform spec set.

## Install spec
```lua
{
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters_by_ft.ruby = { "rubocop" }
    opts.formatters_by_ft.eruby = { "erb_format" }
    opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
      rubocop = {
        command = "rubocop",
        args = { "--server", "--stderr", "--stdin", "$FILENAME", "-a", "--fail-level", "fatal" },
      },
    })
  end,
}
```

## Common customizations
- `--server` — runs rubocop as a daemon for ~10x faster repeated invocations (cold start vs warm).
- `--stderr` — sends rubocop's "Inspecting…" / "Resolving dependencies…" / offense reports to stderr. Without this, bundler chatter leaks into stdout, which conform reads as formatted source and **prepends to your buffer**.
- `-a` — autocorrect safe cops in-place.
- `--fail-level fatal` — only treat fatal as failure; offense violations still get autocorrected but do not surface as conform errors.
- To swap to `bundle exec rubocop`, change `command = "rubocop"` to `command = "bundle"` and prepend `"exec", "rubocop"` to args. (We use direct `rubocop` because the daemon is global.)
- WebFetch https://raw.githubusercontent.com/stevearc/conform.nvim/HEAD/doc/conform.txt for the full formatter schema.

## Our config
Exactly the snippet above. Two filetypes, one formatter override. No format-on-save toggle here — that is set globally in [[format-conform]].

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| _(inherited from conform setup)_ | n/v | `require("conform").format(...)` | See [[format-conform]] for the format keymap |

## Links
- conform.nvim: https://github.com/stevearc/conform.nvim
- rubocop daemon docs: https://docs.rubocop.org/rubocop/usage/server.html
- erb_format: https://github.com/nebulab/erb-formatter
- Sibling doc: [[format-conform]] (core conform setup, format-on-save, keymap)
- Project siblings: [[ruby-ror]], [[ruby-vim-rails]], [[ruby-vim-projectionist]], [[ruby-vim-endwise]]

## Notes
- The stdout-leak bug is the reason for `--stderr`. If you ever see your Ruby files growing a `Resolving dependencies…` header on save, this override regressed.
- The ruby_lsp config in this same file sets `init_options.formatter = "none"` so ruby-lsp does not also try to format — formatting is exclusively conform's job. linters stays `{ "rubocop" }` so ruby-lsp surfaces offenses as LSP diagnostics.
- erb_format must be on `$PATH`: `gem install erb-formatter`.
- Rubocop daemon caches per-project — first format in a project is still slow while it spawns; subsequent formats are sub-100ms.
