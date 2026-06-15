-- Flutter keymaps — buffer-local so they (and the <leader>F "flutter" group)
-- only surface in dart buffers, never globally in which-key. flutter-tools
-- loads via ft=dart, so the :Flutter* commands exist whenever these can fire.
local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
end

map("<leader>Fr", "<cmd>FlutterRun<cr>", "Flutter run")
map("<leader>FR", "<cmd>FlutterReload<cr>", "Flutter hot reload")
map("<leader>FM", "<cmd>FlutterRestart<cr>", "Flutter hot restart")
map("<leader>Fq", "<cmd>FlutterQuit<cr>", "Flutter quit")
map("<leader>Fd", "<cmd>FlutterDevices<cr>", "Flutter devices")
map("<leader>Fe", "<cmd>FlutterEmulators<cr>", "Flutter emulators")
map("<leader>Fl", "<cmd>FlutterLogToggle<cr>", "Flutter log toggle")
map("<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", "Flutter outline")
map("<leader>Fp", "<cmd>FlutterPubGet<cr>", "Flutter pub get")
map("<leader>FP", "<cmd>FlutterPubUpgrade<cr>", "Flutter pub upgrade")
map("<leader>Fc", "<cmd>FlutterLspRestart<cr>", "Flutter LSP restart")

-- Buffer-local "flutter" group label (no-op if which-key isn't loaded yet).
pcall(function()
  require("which-key").add({ { "<leader>F", group = "flutter", buffer = 0 } })
end)
