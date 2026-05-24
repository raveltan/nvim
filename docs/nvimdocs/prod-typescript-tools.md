# prod-typescript-tools
> Native tsserver client for Neovim — replaces ts_ls/vtsls with TS-specific actions.

**Repo:** https://github.com/pmizio/typescript-tools.nvim
**Local spec:** lua/plugins/productivity.lua:4-59
**Tags:** typescript javascript lsp tsserver imports code-action

## Scope
Talks to `tsserver` directly (not via the wrapping `typescript-language-server`), which is faster on large monorepos and unlocks tsserver-only commands (organize imports, add missing imports, remove unused, source definition). We use it **instead of** `ts_ls`/`vtsls` for TS/JS filetypes.

## Install spec
```lua
{
  "pmizio/typescript-tools.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = { settings = { ... } },
  init = function() ... end,
}
```

## Common customizations
- `settings.tsserver_file_preferences` *(table)* — mirrors tsserver's preferences (auto-imports, inlay hints, import specifier style).
- `settings.tsserver_format_options` *(table)* — formatter options passed to tsserver's formatting requests.
- `settings.expose_as_code_action` *(string|table, {})* — surfaces internal commands as code actions; `"all"` or list (`fix_all`, `add_missing_imports`, `remove_unused`, `remove_unused_imports`, `organize_imports`).
- `settings.complete_function_calls` *(bool, false)* — auto-add `()` and snippet args after function completions.
- `settings.include_completions_with_insert_text` *(bool, true)* — include items that need `insert_text` (required for auto-imports).
- `settings.code_lens` *("off"|"all"|"implementations_only"|"references_only", "off")* — code lens for refs/impls.
- `settings.disable_member_code_lens` *(bool, true)* — hide lens on class members when code_lens is on.
- `settings.tsserver_plugins` *(table, {})* — load tsserver plugins (e.g. styled-components, Vue).
- `settings.tsserver_max_memory` *("auto"|number, "auto")* — Node heap MB.
- `settings.separate_diagnostic_server` *(bool, true)* — run a second tsserver process for diagnostics.
- `settings.publish_diagnostic_on` *("insert_leave"|"change", "insert_leave")* — when diagnostics fire.

See https://github.com/pmizio/typescript-tools.nvim#%EF%B8%8F-configuration.

## Our config
- `tsserver_file_preferences`:
  - `importModuleSpecifierPreference = "relative"`
  - `includePackageJsonAutoImports = "auto"`
  - All `includeInlay*Hints` disabled (no inlay hints).
- `tsserver_format_options`:
  - `allowIncompleteCompletions = false`
  - `allowRenameOfImportPath = false`
- `expose_as_code_action = { "fix_all", "add_missing_imports", "remove_unused" }`
- `complete_function_calls = false`
- `include_completions_with_insert_text = true`
- `code_lens = "off"` and `disable_member_code_lens = true`
- **`init` autocmds:**
  - `FileType` (ts/tsx/js/jsx) → buffer-local keymaps below.
  - `BufWritePre` (`*.ts,*.tsx,*.js,*.jsx`) in augroup `ts_organize_on_save` → runs `TSToolsAddMissingImports sync` then `TSToolsRemoveUnusedImports sync`. Skipped if `vim.g.disable_ts_organize_on_save` is set. Shows `vim.notify` toast.

## Keymaps
Buffer-local on TS/JS filetypes.

| Key | Action | Desc |
|---|---|---|
| `<leader>co` | `:TSToolsOrganizeImports` | Organize imports |
| `<leader>cM` | `:TSToolsAddMissingImports` | Add missing imports |
| `<leader>cU` | `:TSToolsRemoveUnusedImports` | Remove unused imports |
| `<leader>cR` | `:TSToolsRemoveUnused` | Remove unused (decls + imports) |
| `<leader>cF` | `:TSToolsFixAll` | Fix all |
| `<leader>cD` | `:TSToolsGoToSourceDefinition` | Go to source definition |

## Links
- README: https://github.com/pmizio/typescript-tools.nvim
- Commands: https://github.com/pmizio/typescript-tools.nvim#-commands
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md), [prod-template-string](prod-template-string.md)

## Notes
- Do **not** also enable `ts_ls`/`vtsls` in lsp.lua — duplicate clients fight over diagnostics. Our `lsp.lua` excludes them.
- The on-save organize is sync, so very large files visibly stall the write. Toggle off with `:lua vim.g.disable_ts_organize_on_save = true`.
- `GoToSourceDefinition` skips `.d.ts` and lands on the actual `.ts` source — gold for following imports into node_modules.
