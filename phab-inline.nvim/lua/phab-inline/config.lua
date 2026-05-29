-- Plugin configuration: defaults, current values, and script-path resolution.

local M = {}

-- Absolute path to the bundled scripts/ dir, derived from this file's location.
-- This file lives at <plugin>/lua/phab-inline/config.lua, so scripts/ is two
-- directories up.
local function plugin_script(name)
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  local here = vim.fn.fnamemodify(src, ":h")        -- .../lua/phab-inline
  local root = vim.fn.fnamemodify(here, ":h:h")     -- plugin root
  return root .. "/scripts/" .. name
end

M.script_path = plugin_script

local default_config = {
  script = plugin_script("phab-inline-comments.sh"),
  -- Script used to fetch non-inline (general) revision comments.
  comments_script = plugin_script("phab-comments.sh"),
  -- Truncate first-line preview at end-of-line virtual text
  virt_text_max = 100,
  -- Auto-fetch on BufReadPost / BufEnter
  auto = true,
  -- No keymaps are installed by default. Pass a table to setup() to opt in,
  -- e.g. keys = { open_all = "<leader>pi", refresh = "<leader>pr", ... }.
  -- Supported entries: open_all, refresh, clear, toggle, next, prev,
  -- comments, description, edit_summary, edit_test_plan.
  keys = false,
}

local config = vim.deepcopy(default_config)

function M.get() return config end

function M.set(user_config)
  user_config = user_config or {}
  -- tbl_deep_extend("force", false, table) replaces with the table, and
  -- ("force", false, false) keeps false, so a simple force-merge is enough.
  config = vim.tbl_deep_extend("force", default_config, user_config)
  -- Defensive: if the user explicitly passed keys = false, preserve that.
  if user_config.keys == false then config.keys = false end
  return config
end

return M
