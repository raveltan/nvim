-- Xcodebuild keymaps — buffer-local so they (and the <leader>X "xcode" group)
-- only surface in swift buffers, never globally in which-key. xcodebuild.nvim
-- loads via ft=swift, so the :Xcodebuild* commands exist whenever these can
-- fire.
local function map(lhs, rhs, desc, mode)
  vim.keymap.set(mode or "n", lhs, rhs, { buffer = true, desc = desc })
end

-- <leader>X* is skipped under the GAF profile: GAF registers global Xdebug
-- maps on that prefix (lua/gaf/xdebug.lua setup) and mixing the two groups
-- would make which-key show both. GAF session → xdebug owns <leader>X;
-- xcodebuild actions stay reachable via :XcodebuildPicker. The test/debug
-- maps further down have no such clash and are always set.
if not vim.g.gaf then
  map("<leader>XX", "<cmd>XcodebuildPicker<cr>", "All xcodebuild actions")
  map("<leader>Xb", "<cmd>XcodebuildBuild<cr>", "Build")
  map("<leader>XB", "<cmd>XcodebuildBuildForTesting<cr>", "Build for testing")
  map("<leader>Xr", "<cmd>XcodebuildBuildRun<cr>", "Build & run")
  map("<leader>Xl", "<cmd>XcodebuildToggleLogs<cr>", "Toggle logs")
  map("<leader>Xe", "<cmd>XcodebuildTestExplorerToggle<cr>", "Test explorer")
  map("<leader>Xc", "<cmd>XcodebuildToggleCodeCoverage<cr>", "Toggle coverage")
  map("<leader>XC", "<cmd>XcodebuildShowCodeCoverageReport<cr>", "Coverage report")
  map("<leader>Xs", "<cmd>XcodebuildSelectScheme<cr>", "Select scheme")
  map("<leader>Xd", "<cmd>XcodebuildSelectDevice<cr>", "Select device")
  map("<leader>Xt", "<cmd>XcodebuildSelectTestPlan<cr>", "Select test plan")
  map("<leader>Xp", "<cmd>XcodebuildPreviewGenerateAndShow<cr>", "SwiftUI preview")
  map("<leader>XP", "<cmd>XcodebuildPreviewToggle<cr>", "Toggle SwiftUI preview")
  map("<leader>Xa", "<cmd>XcodebuildCodeActions<cr>", "Code actions")
  map("<leader>Xf", "<cmd>XcodebuildProjectManager<cr>", "Project manager (files/targets)")
  map("<leader>Xq", "<cmd>XcodebuildQuickfixLine<cr>", "Quickfix line")

  -- Buffer-local "xcode" group label (no-op if which-key isn't loaded yet).
  pcall(function()
    require("which-key").add({ { "<leader>X", group = "xcode", buffer = 0 } })
  end)
end

-- Tests — mirrors the neotest <leader>t* convention (config/autocmds.lua);
-- swift uses xcodebuild's own runner, there is no neotest adapter.
map("<leader>tr", "<cmd>XcodebuildTestNearest<cr>", "Run nearest test")
map("<leader>tf", "<cmd>XcodebuildTestClass<cr>", "Run class tests")
map("<leader>tt", "<cmd>XcodebuildTest<cr>", "Run test plan")
map("<leader>ts", "<cmd>XcodebuildTestSelected<cr>", "Run selected tests", "v")
map("<leader>t.", "<cmd>XcodebuildTestRepeat<cr>", "Repeat last tests")
map("<leader>tF", "<cmd>XcodebuildTestFailing<cr>", "Run failing tests")

-- Debug — extends the global <leader>d* DAP maps (lua/plugins/dap.lua).
map("<leader>dd", function() require("xcodebuild.integrations.dap").build_and_debug() end, "Build & debug")
map("<leader>dr", function() require("xcodebuild.integrations.dap").debug_without_build() end, "Debug without build")
map("<leader>td", function() require("xcodebuild.integrations.dap").debug_func_test() end, "Debug nearest test")
