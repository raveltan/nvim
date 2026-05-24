# flutter-tools
> Flutter/Dart toolchain plugin — owns dartls, hot reload/restart, device selection, and Flutter's DAP.

**Repo:** https://github.com/akinsho/flutter-tools.nvim
**Local spec:** lua/plugins/flutter.lua:1-70
**Tags:** flutter dart lsp dap hot-reload mobile fvm

## Scope
Wraps the `flutter` CLI inside Neovim: starts/stops apps, streams stdout into a `dev_log` buffer, exposes hot reload/restart, lists devices and emulators, drives `pub get`/`pub upgrade`, and configures the Dart LSP (`dartls`). Also registers a DAP adapter so breakpoint debugging works via the Flutter debug protocol.

dartls is **owned by this plugin** — do NOT add it to mason-lspconfig (see header comment in `flutter.lua`) or two LSP clients will fight.

## Install spec
```lua
{
  "akinsho/flutter-tools.nvim",
  ft = { "dart" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "neovim/nvim-lspconfig",
    "saghen/blink.cmp",
  },
  keys = { ... <leader>F* ... },
  opts = function() return { ui = {...}, decorations = {...}, dev_log = {...}, debugger = {...}, lsp = {...} } end,
}
```

## Common customizations
- `ui.border` *(string, `"single"`)* — float border style. We use `"rounded"`.
- `ui.notification_style` *(`"native"|"plugin"`)* — `"native"` uses `vim.notify`; `"plugin"` uses nvim-notify-style floats.
- `decorations.statusline` *(table)* — show `app_version`, `device`, `project_config` in the statusline via `vim.g.flutter_tools_decorations`.
- `widget_guides.enabled` *(bool)* — virtual-line guides for nested widgets.
- `closing_tags` *(table)* — append `// WidgetName` after long closing parens; `highlight`, `prefix`, `enabled` fields.
- `dev_log.enabled` *(bool)* / `dev_log.open_cmd` *(string)* — where the run log opens (`"tabedit"`, `"botright 15split"`, etc.).
- `dev_log.focus_on_open` *(bool, `true`)* — whether to jump to the log window.
- `outline.open_cmd` *(string)* / `outline.auto_open` *(bool)* — widget outline window.
- `debugger.enabled` *(bool)* — register `dart`/`flutter` DAP adapter.
- `debugger.run_via_dap` *(bool)* — when `true`, `:FlutterRun` itself goes through nvim-dap (vs. flutter-tools' own runner). We keep this `false`.
- `debugger.register_configurations` *(fun(paths))* — populate `require('dap').configurations.dart`.
- `flutter_path` *(string)* / `flutter_lookup_cmd` *(string)* — explicit binary or lookup command. For **fvm**: `flutter_lookup_cmd = "dirname $(which flutter)"` after `fvm use`, or set `flutter_path = vim.fn.getcwd() .. "/.fvm/flutter_sdk/bin/flutter"`. We rely on system flutter — fvm users need to override.
- `fvm` *(bool, `false`)* — newer versions of flutter-tools support a literal `fvm = true` flag that auto-detects `.fvm/flutter_sdk`. WebFetch https://raw.githubusercontent.com/akinsho/flutter-tools.nvim/HEAD/README.md if unsure which release added it.
- `lsp.color` *(table)* — color preview decorations (`enabled`, `background`, `virtual_text`).
- `lsp.on_attach` *(fun(client, bufnr))* — usual LSP attach hook.
- `lsp.capabilities` *(table)* — completion capabilities.
- `lsp.settings` *(table)* — passed to dartls as workspace config (see [Dart Code settings](https://github.com/Dart-Code/Dart-Code/blob/master/package.json)).

## Our config
- `ui = { border = "rounded", notification_style = "native" }` — matches LSP UI; uses `vim.notify`.
- `decorations.statusline = { app_version = false, device = true, project_config = false }` — only the device is surfaced.
- `widget_guides.enabled = true` — visual nesting guides.
- `closing_tags = { highlight = "Comment", prefix = "// ", enabled = true }`.
- `dev_log = { enabled = true, open_cmd = "tabedit" }` — log opens in a new tab.
- `outline = { open_cmd = "30vnew", auto_open = false }` — manual toggle via `<leader>Fo`.
- `debugger`: enabled, `run_via_dap = false`. `register_configurations` sets a single launch config: `type = "dart"`, `request = "launch"`, `name = "Launch Flutter"`, `dartSdkPath = "dart"`, `flutterSdkPath = "flutter"`, `program = "${workspaceFolder}/lib/main.dart"`, `cwd = "${workspaceFolder}"`.
- `lsp.color = { enabled = true, background = false, virtual_text = true }` — color swatches as virtual text.
- `lsp.on_attach` nils out `client.server_capabilities.semanticTokensProvider` — disables dartls semantic tokens so treesitter highlighting wins (avoids flicker / dim colors).
- `lsp.capabilities = blink.cmp.get_lsp_capabilities()`.
- `lsp.settings`: `showTodos = true`, `completeFunctionCalls = true`, `renameFilesWithClasses = "prompt"`, `updateImportsOnRename = true`, `enableSnippets = true`.

## Keymaps
All under `<leader>F` (capital F, since lowercase `<leader>f` is owned by find/telescope-ish):

| Key | Command | Desc |
|---|---|---|
| `<leader>Fr` | `:FlutterRun` | Run app on selected device |
| `<leader>FR` | `:FlutterReload` | Hot reload |
| `<leader>FM` | `:FlutterRestart` | Hot restart |
| `<leader>Fq` | `:FlutterQuit` | Quit running app |
| `<leader>Fd` | `:FlutterDevices` | Pick device |
| `<leader>Fe` | `:FlutterEmulators` | Launch emulator |
| `<leader>Fl` | `:FlutterLogToggle` | Toggle dev log window |
| `<leader>Fo` | `:FlutterOutlineToggle` | Toggle widget outline |
| `<leader>Fp` | `:FlutterPubGet` | `flutter pub get` |
| `<leader>FP` | `:FlutterPubUpgrade` | `flutter pub upgrade` |
| `<leader>Fc` | `:FlutterLspRestart` | Restart dartls |

Step-debug keys are the generic nvim-dap ones — see [[dap-nvim-dap]].

## Links
- README: https://github.com/akinsho/flutter-tools.nvim
- Help: `:help flutter-tools.txt`
- Dart LSP settings: https://github.com/Dart-Code/Dart-Code/blob/master/package.json
- Related: [[dap-nvim-dap]], [[lsp-nvim-lspconfig]], [[cmp-blink]]

## Notes
- `keys` is a lazy.nvim trigger — opening a Dart file alone won't load the plugin; pressing any `<leader>F*` (or `ft = "dart"`) does. The first load also auto-starts dartls.
- `run_via_dap = false` means `:FlutterRun` uses flutter-tools' built-in process runner. Breakpoint debugging still works because `debugger.enabled = true` registers the DAP adapter and a `dart` configuration — invoke via `:DapContinue` after launching.
- `register_configurations` always overwrites `dap.configurations.dart` to a single entry. If you need multiple targets (e.g. `main_dev.dart` vs `main_prod.dart`), append to the table instead of reassigning.
- The `on_attach` semantic-tokens nil-out is a deliberate workaround for dartls + treesitter color clashes — remove it if you prefer LSP semantic highlighting.
- For **fvm**: this spec does not configure fvm. Add `flutter_path` or `flutter_lookup_cmd` to `opts` per-project (e.g. via `.nvim.lua` exrc) if your project uses a pinned Flutter SDK.
