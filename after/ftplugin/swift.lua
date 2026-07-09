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
  map("<leader>Xg", "<cmd>SwiftBuildServer<cr>", "Generate buildServer.json (LSP)")

  -- Buffer-local "xcode" group label (no-op if which-key isn't loaded yet).
  pcall(function()
    require("which-key").add({ { "<leader>X", group = "xcode", buffer = 0 } })
  end)
end

-- Regenerate buildServer.json so sourcekit-lsp can resolve symbols in an
-- .xcodeproj / .xcworkspace (plain SPM Package.swift needs none). xcodebuild.nvim
-- only autogenerates this on a build STARTED FROM NVIM — build in Xcode instead
-- and sourcekit reports every cross-file symbol (ContentView, models, framework
-- imports) as unknown until this runs. Detects the container + scheme, writes
-- buildServer.json at the project root, then restarts the LSP so root_dir
-- re-resolves onto the new file. Also exposed as :SwiftBuildServer.
local function regen_build_server()
  local fname = vim.api.nvim_buf_get_name(0)
  local function find_up(pat)
    return vim.fs.find(function(n) return n:match(pat) end,
      { path = fname, upward = true, type = "directory", limit = 1 })[1]
  end
  -- Workspace wins over bare project (matches sourcekit's own root order).
  local ws, proj = find_up("%.xcworkspace$"), find_up("%.xcodeproj$")
  local container = ws or proj
  if not container then
    vim.notify("SwiftBuildServer: no .xcworkspace/.xcodeproj found upward", vim.log.levels.ERROR)
    return
  end
  local root = vim.fs.dirname(container)
  local flag = ws and "-workspace" or "-project"

  local function run(scheme)
    vim.notify("xcode-build-server: generating buildServer.json (" .. scheme .. ")...")
    vim.system({ "xcode-build-server", "config", flag, container, "-scheme", scheme },
      { text = true, cwd = root }, function(r)
        vim.schedule(function()
          if r.code == 0 then
            vim.notify("buildServer.json written at " .. root .. " — restarting sourcekit")
            pcall(vim.cmd, "LspRestart sourcekit")
          else
            vim.notify("xcode-build-server failed:\n" .. ((r.stderr or "") .. (r.stdout or "")),
              vim.log.levels.ERROR)
          end
        end)
      end)
  end

  -- Ask xcodebuild for the scheme list; prompt only when there is more than one.
  vim.system({ "xcodebuild", "-list", "-json", flag, container },
    { text = true, cwd = root }, function(o)
      local schemes = {}
      local ok, parsed = pcall(vim.json.decode, o.stdout or "")
      if ok then schemes = (parsed.workspace or parsed.project or {}).schemes or {} end
      vim.schedule(function()
        if #schemes == 0 then
          vim.notify("SwiftBuildServer: no schemes (xcodebuild -list failed)", vim.log.levels.ERROR)
        elseif #schemes == 1 then
          run(schemes[1])
        else
          vim.ui.select(schemes, { prompt = "Scheme for buildServer.json:" }, function(c)
            if c then run(c) end
          end)
        end
      end)
    end)
end

vim.api.nvim_buf_create_user_command(0, "SwiftBuildServer", regen_build_server,
  { desc = "Generate buildServer.json + restart sourcekit-lsp" })

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
