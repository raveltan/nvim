local last_query = { files = "", grep = "" }

local function patch_close_once()
  local picker_ui = require("fff.picker_ui")
  if picker_ui._last_query_patched then return end
  picker_ui._last_query_patched = true
  local original_close = picker_ui.close
  picker_ui.close = function(...)
    local mode = picker_ui.state.mode == "grep" and "grep" or "files"
    last_query[mode] = picker_ui.state.query or ""
    return original_close(...)
  end
end

return {
  {
    "dmtrKovalenko/fff.nvim",
    version = "*",
    build = function() require("fff.download").download_or_build_binary() end,
    cmd = { "FFFScan", "FFFRefreshGit", "FFFClearCache", "FFFHealth", "FFFDebug", "FFFOpenLog" },
    keys = {
      { "<leader><leader>", function() require("fff").find_files() end, desc = "Find files" },
      { "<leader>fo", function()
          -- %:p:h = current file's dir; fall back to cwd for unnamed buffers.
          local dir = vim.fn.expand("%:p:h")
          if dir == "" then dir = vim.fn.getcwd() end
          vim.ui.open(dir)
        end, desc = "Open file dir in Finder" },
      { "<leader>sg", function() patch_close_once(); require("fff").live_grep() end, desc = "Live grep" },
      { "<leader>sw", function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end, mode = { "n", "x" }, desc = "Grep word" },
      { "<leader>sz", function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end, desc = "Fuzzy grep" },
      { "<leader>s.", function() require("fff").live_grep({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Grep in current file dir" },
    },
    opts = {
      prompt = "  ",
      title = " Files",
      max_results = 100,
      layout = {
        height = 0.85,
        width = 0.85,
        prompt_position = "top",
        preview_position = "right",
        preview_size = 0.55,
        flex = { size = 130, wrap = "top" },
      },
      preview = { line_numbers = true },
      keymaps = {
        focus_list = "<C-l>",
        focus_preview = "<C-p>",
        preview_scroll_up = "<M-u>",
      },
      frecency = { enabled = true },
      history = { enabled = true },
      grep = { smart_case = true, time_budget_ms = 200 },
    },
  },
}
