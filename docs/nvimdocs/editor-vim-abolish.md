# editor-vim-abolish

> ⚠️ **REMOVED** — plugin is no longer in this config (replaced by text-case.nvim — `<leader>cv` opens a convert-case picker (see config-keymaps)). Doc kept for history.
> Case-preserving search/replace (`:S`/`:Subvert`) and `cr*` case coercions.

**Repo:** https://github.com/tpope/vim-abolish
**Local spec:** lua/plugins/editor.lua:486
**Tags:** case, refactor, search-replace, vimscript, tpope

## Scope

`vim-abolish` ships two distinct features:

1. **`:Subvert`** (`:S`) — case- and inflection-aware substitution. `:%S/facilit{y,ies}/building{,s}/g` replaces facility→building, Facility→Building, FACILITY→BUILDING, facilities→buildings in one pass.
2. **`cr*` coercions** — operator-pending motions that rewrite the word under cursor between cases: snake, camel, mixed (Pascal), upper, dash, dot, title, space.

## Install spec

```lua
{ "tpope/vim-abolish", event = "VeryLazy" }
```

Lazy on `VeryLazy`. Pure vimscript; no `opts`. The `cr` operator works once the plugin is sourced.

## Common customizations

- `vim.g.abolish_save_file` *(string)* — path for the persistent `Abolish` dictionary (custom `Abolish from to` aliases). Default: `~/.vim/after/plugin/abolish.vim`.
- `vim.g.abolish_no_cmdline_abbreviations` *(bool, 0)* — set `1` to skip the `:%s -> :%S` cmdline abbreviation rewrite.
- `:Abolish [-buffer] {bad} {good}` *(cmd)* — register a typo-correction alias that auto-applies on insert.

WebFetch https://raw.githubusercontent.com/tpope/vim-abolish/HEAD/README.markdown if uncertain.

## Our config

Zero configuration. The `cr*` family is namespaced under `which-key`'s `<leader>cv` "case convert" group label but the actual key sequence is the native `cr` operator, not a leader binding.

## Keymaps

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `crs` | n | coerce to snake_case | `someWord` → `some_word` |
| `crc` | n | coerce to camelCase | `some_word` → `someWord` |
| `crm` | n | coerce to MixedCase | `some_word` → `SomeWord` (PascalCase) |
| `cru` | n | coerce to UPPER_CASE | `someWord` → `SOME_WORD` |
| `cr-` | n | coerce to dash-case | `some_word` → `some-word` |
| `cr.` | n | coerce to dot.case | `some_word` → `some.word` |
| `cr<space>` | n | coerce to space case | `some_word` → `some word` |
| `crt` | n | coerce to Title Case | `some_word` → `Some Word` |
| `crk` | n | coerce to kebab-case | (alias of `cr-`) |
| `:S/{pat}/{rep}/[flags]` | cmd | case-aware substitution | Case-preserving `:s` |
| `:Subvert/{pat}/{rep}/[flags]` | cmd | long form of `:S` | Identical to `:S` |
| `:Abolish {bad} {good}` | cmd | register correction | Persistent typo fix |

Coercions repeat with `.` via [[editor-vim-repeat]].

## Links

- Plugin repo: https://github.com/tpope/vim-abolish
- Help: `:help abolish`

## Notes

- `:S` syntax accepts brace alternation: `:S/{man,woman}/{husband,wife}/g`. Order matters — first alt maps to first replacement.
- `cr*` operates on the inner-word (`iw`) by default. Combine with motions: `cr2w` to coerce two words, but behaviour is operator-specific — test before relying.
- Companion to [[editor-vim-repeat]] which makes the `cr*` family repeatable.
