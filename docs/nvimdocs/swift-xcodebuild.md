# swift-xcodebuild
> Swift/SwiftUI toolchain — xcodebuild.nvim owns build/run/test/debug for Xcode projects and Swift packages; sourcekit-lsp handles LSP.

**Repo:** https://github.com/wojciech-kulik/xcodebuild.nvim
**Local spec:** lua/plugins/swift.lua · keymaps in after/ftplugin/swift.lua · LSP in lua/plugins/lsp.lua (sourcekit block)
**Tags:** swift swiftui xcode ios macos lsp dap simulator previews

## Scope
Wraps `xcodebuild`/`xcrun` inside Neovim: builds, installs, and runs apps on simulators and physical devices, runs tests (nearest/class/plan/selected/failing) with a visual test explorer, reports per-line code coverage, parses build logs into diagnostics/quickfix, renders SwiftUI previews inline (snacks.nvim `image`), and manages project files/targets (`xcp`). Registers `dap.configurations.swift` against the `lldb-dap` adapter bundled with Xcode 16+ via `require("xcodebuild.integrations.dap").setup(false)` — `false` because persistent-breakpoints.nvim already owns breakpoint restore.

LSP is **not** owned by this plugin: `sourcekit-lsp` ships with the Xcode toolchain (not mason) and is registered in `lua/plugins/lsp.lua` behind an executable check, with `didChangeWatchedFiles.dynamicRegistration` forced on (sourcekit needs it for cross-file updates) and filetypes restricted to `swift` (defaults also claim c/cpp/objc).

## The xcode-build-server bridge
Bare sourcekit-lsp only understands SPM packages (`Package.swift`). For `.xcodeproj`/`.xcworkspace` projects it needs a Build Server Protocol bridge: `xcode-build-server` (brew). `:XcodebuildSetup` (`<leader>mS`) — run once per project root — picks scheme/device/test plan and generates `buildServer.json`, which makes the LSP fully functional (completion, cross-file navigation, diagnostics). xcodebuild.nvim's own xcode-build-server integration also regenerates `buildServer.json` (and restarts sourcekit) on every scheme change, so no separate regen command is needed.

## External tools
```sh
brew install xcode-build-server xcbeautify swiftformat swiftlint xcp
pipx install pymobiledevice3   # only for physical-device debugging
```
- `xcbeautify` — build log formatting
- `swiftformat` — conform formatter (`lua/plugins/formatting.lua`, manual `<leader>cf`)
- `swiftlint` — nvim-lint on save (guarded by executable check)
- `xcp` — project-file management (add/rename/delete files updates the pbxproj)

## Install spec
```lua
{
  "wojciech-kulik/xcodebuild.nvim",
  ft = { "swift" }, -- sole load trigger; <leader>m* maps live in after/ftplugin/swift.lua
  dependencies = {
    "MunifTanjim/nui.nvim",
    "folke/snacks.nvim", -- picker + image (SwiftUI previews)
  },
  config = function()
    require("xcodebuild").setup({ logs = {...}, code_coverage = { enabled = true } })
    require("xcodebuild.integrations.dap").setup(false)
  end,
}
```

## SwiftUI previews
`<leader>mp` (`:XcodebuildPreviewGenerateAndShow`) builds and renders the current view as an image in a split — needs an image-capable terminal (kitty/ghostty/wezterm) and the `xcodebuild-nvim-preview` Swift package added to the project. Generate-on-demand, not Xcode's live canvas.

## Notes / gotchas
- Treesitter `swift` parser added to the install list (`lua/plugins/treesitter.lua`).
- No neotest adapter for swift — `<leader>t*` maps in swift buffers call `:XcodebuildTest*` directly (swift is deliberately absent from the neotest FileType pattern in `config/autocmds.lua`).
- Xcode < 16 would need the codelldb adapter instead (`integrations.codelldb` in setup opts + mason's codelldb binary); current machine runs Xcode 26, so bundled `lldb-dap` is used.
- `<leader>m*` xcode maps use `<leader>m` ("make") rather than `<leader>X`: no Shift, and it never clashes with GAF's global Xdebug maps (`<leader>X*`, GAF-gated in `lua/plugins/editor.lua`). So the xcode maps are now set in every profile, GAF or not.
- Interface Builder, signing, and App Store submission still need Xcode proper.
