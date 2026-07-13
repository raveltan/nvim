# lsp-vtsls
> TypeScript/JavaScript LSP — vtsls wraps the VS Code TypeScript extension as a language server.

**Repo:** https://github.com/yioneko/vtsls
**Local spec:** lua/plugins/lsp.lua (with the other `vim.lsp.config` servers; mason `ensure_installed`)
**Tags:** typescript, javascript, lsp, tsserver

## Scope
Full VS Code TS feature set over LSP: completions, diagnostics, source actions (organize/add/remove imports, fix all), `typescript.goToSourceDefinition`, and import updates on file rename (`workspace/willRenameFiles`, used by `Snacks.rename`). Migrated from `pmizio/typescript-tools.nvim` (maintenance drift — its issue #273 recommends vtsls).

## Our config
- `typescript.tsserver.maxTsServerMemory = 8192` — fl-gaf OOMs the default heap.
- `typescript.preferences.importModuleSpecifier` — `project-relative` under GAF (eslint validate-freelancer-imports), `relative` otherwise.
- `typescript.preferences.includePackageJsonAutoImports = "auto"`.
- `typescript/javascript.updateImportsOnFileMove.enabled = "always"`.
- Formatting stays with conform (prettierd); linting stays with the eslint LSP.

## Keymaps (buffer-local, ts/tsx/js/jsx)
| Key | Action | Mechanism |
|---|---|---|
| `<leader>co` | Organize imports (sort + drop unused) | code action `source.organizeImports` |
| `<leader>cM` | Add missing imports | code action `source.addMissingImports.ts` |
| `<leader>cU` | Remove unused imports | code action `source.removeUnusedImports` |
| `<leader>cx` | Remove all unused code | code action `source.removeUnused.ts` |
| `<leader>cF` | Fix all diagnostics | code action `source.fixAll.ts` |
| `<leader>cD` | Go to source definition (.ts not .d.ts) | command `typescript.goToSourceDefinition` |

`<leader>cx` not `cR` — angular/init.lua owns `<leader>cR` (`goto_route`) on typescript buffers.

## Links
- Related: [editor-angular](editor-angular.md) — Angular nav layered on top; blink `angular_inputs` source prepends to the typescript source list.
- Related: [lsp-nvim-lspconfig](lsp-nvim-lspconfig.md), [lsp-mason-lspconfig](lsp-mason-lspconfig.md)

## Notes
- Settings live under `typescript.*` / `javascript.*` (VS Code namespaces), NOT `vtsls.*` — that namespace only holds wrapper options (`vtsls.autoUseWorkspaceTsdk`, `vtsls.experimental.*`).
- Code lens stays off (no `vim.lsp.codelens.enable()` anywhere) — deliberate, config-wide.
- TypeScript 7 (tsgo, Go-native) ships its own LSP but Angular doesn't support it yet — revisit when the Angular roadmap moves past "prototyping".
