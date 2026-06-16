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
      { "<leader><leader>", function() patch_close_once(); require("fff").find_files({ query = last_query.files }) end, desc = "Find files (resume last query)" },
      { "<leader>ff", function() require("fff").find_files() end, desc = "Find files" },
      { "<leader>fd", function()
          -- Query prefill instead of find_files_in_dir: change_indexing_directory
          -- permanently re-points the index at the subdir (and re-indexes), so all
          -- later <leader>ff searches would silently stay scoped there.
          local dir = vim.fn.expand("%:.:h")
          local query = (dir ~= "" and dir ~= ".") and (dir .. "/") or ""
          require("fff").find_files({ query = query })
        end, desc = "Files in buffer dir" },
      { "<leader>fc", function()
          local cwd = vim.fn.getcwd()
          require("fff").find_files_in_dir(vim.fn.stdpath("config"))
          local win = require("fff.picker_ui").state.input_win
          if win then
            -- WinClosed's pattern is matched against the window ID, so this
            -- fires only when the picker's input window closes (picker_ui.close
            -- always closes input_win), not on unrelated floats — a patternless
            -- once=true autocmd was consumed by ANY closing window (fidget,
            -- notifications), restoring the index under the open picker.
            vim.api.nvim_create_autocmd("WinClosed", {
              pattern = tostring(win),
              once = true,
              callback = function() pcall(require("fff").change_indexing_directory, cwd) end,
            })
          else
            -- Picker failed to open but find_files_in_dir already re-pointed
            -- the index; restore immediately.
            pcall(require("fff").change_indexing_directory, cwd)
          end
        end, desc = "Config files" },
      { "<leader>fo", function()
          -- %:p:h = current file's dir; fall back to cwd for unnamed buffers.
          local dir = vim.fn.expand("%:p:h")
          if dir == "" then dir = vim.fn.getcwd() end
          vim.ui.open(dir)
        end, desc = "Open file dir in Finder" },
      { "<leader>sg", function() patch_close_once(); require("fff").live_grep() end, desc = "Live grep" },
      { "<leader>sG", function() patch_close_once(); require("fff").live_grep({ query = last_query.grep }) end, desc = "Live grep (resume last query)" },
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
