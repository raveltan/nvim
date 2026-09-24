-- Defaults, setup() merging, and resolution of the bundled script paths.
--
-- The scripts live in the config's own scripts/phab/ dir, not in a plugin
-- directory: this module is part of the config (lua/gaf/phab/), so the path is
-- derived from this file's location rather than from a lazy.nvim plugin root.

local M = {}

local function script(name)
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  local here = vim.fn.fnamemodify(src, ":h")       -- <config>/lua/gaf/phab
  local root = vim.fn.fnamemodify(here, ":h:h:h")  -- <config>
  return root .. "/scripts/phab/" .. name
end

M.script_path = script

local defaults = {
  script = script("phab-inline-comments.sh"),
  comments_script = script("phab-comments.sh"),
  -- Fetch and render on BufReadPost / BufEnter once a revision is known.
  auto = true,
  -- When entering a worktree whose revision nothing identifies, ask for it.
  -- Asked at most once per worktree per session; declining is remembered.
  prompt_on_open = true,
  -- How :PhabSuggest renders the rewritten lines. "code" posts the
  -- replacement alone, "diff" posts it against the original as lang=diff.
  -- Phabricator has no structured suggestion field; both are remarkup.
  suggest_style = "code",
  -- The comment compose float. Saving is `:w` (the buffer is acwrite) and
  -- discarding is `:q`; `save` binds an extra normal-mode key if you want one,
  -- `discard` replaces the quick-close keys. Either takes a key, a list of
  -- keys, or false.
  compose = {
    width   = 0.7,
    height  = 0.4,
    save    = false,
    discard = { "q", "<esc>" },
  },
  -- Base URL for :PhabOpen. Conduit itself reads $PHABRICATOR_URL / ~/.arcrc.
  url = vim.env.PHABRICATOR_URL or "https://phabricator.tools.flnltd.com",
  -- Keymaps. Set an entry to false to skip it, or keys = false to install none.
  -- ]p / [p shadow the builtin put-with-indent mappings.
  keys = {
    open_all       = "<leader>pi",
    revision       = "<leader>pv",
    browser        = "<leader>po",
    list           = "<leader>pl",
    refresh        = "<leader>pr",
    clear          = "<leader>pc",
    toggle         = "<leader>pt",
    comments       = "<leader>pm",
    description    = "<leader>pd",
    edit_summary   = "<leader>pS",
    edit_test_plan = "<leader>pP",
    comment        = "<leader>pa",
    suggest        = "<leader>pe",
    draft_edit     = "<leader>pE",
    draft_delete   = "<leader>pX",
    submit         = "<leader>ps",
    drafts         = "<leader>pD",
    next           = "]p",
    prev           = "[p",
  },
}

local config = vim.deepcopy(defaults)

function M.get() return config end

function M.set(user_config)
  user_config = user_config or {}
  config = vim.tbl_deep_extend("force", defaults, user_config)
  -- deep_extend would merge the defaults back in over an explicit opt-out.
  if user_config.keys == false then config.keys = false end
  return config
end

return M
