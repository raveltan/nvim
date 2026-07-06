-- Swift/SwiftUI support. xcodebuild.nvim owns building, running, testing, and
-- debugging Xcode projects / Swift packages (simulators + physical devices),
-- plus test explorer, code coverage, and SwiftUI previews (rendered via the
-- snacks.nvim image module + the xcodebuild-nvim-preview Swift package).
--
-- sourcekit-lsp is registered in lua/plugins/lsp.lua (ships with Xcode, not
-- mason). For .xcodeproj/.xcworkspace projects it needs xcode-build-server:
--   brew install xcode-build-server xcbeautify swiftformat swiftlint xcp
-- Plain SPM packages (Package.swift) work without it.
--
-- Per project: run :XcodebuildSetup once in the project root — picks scheme /
-- device / test plan and generates buildServer.json for the LSP.
--
-- <leader>X* / <leader>t* / <leader>d* maps live in after/ftplugin/swift.lua.
return {
  {
    "wojciech-kulik/xcodebuild.nvim",
    ft = { "swift" },
    dependencies = {
      "MunifTanjim/nui.nvim",
      "folke/snacks.nvim", -- picker + image (SwiftUI previews)
    },
    config = function()
      require("xcodebuild").setup({
        logs = {
          auto_open_on_success_tests = false,
          auto_open_on_failed_tests = false,
          auto_open_on_success_build = false,
          auto_open_on_failed_build = true,
          auto_close_on_app_launch = true,
          only_summary = true,
        },
        code_coverage = { enabled = true },
      })

      -- Registers dap.configurations.swift + the lldb-dap adapter bundled with
      -- Xcode 16+ (older Xcode needs integrations.codelldb enabled instead).
      -- `false` = skip xcodebuild's own breakpoint restore on BufReadPost —
      -- persistent-breakpoints.nvim (lua/plugins/dap.lua) already owns that.
      require("xcodebuild.integrations.dap").setup(false)
    end,
  },
}
