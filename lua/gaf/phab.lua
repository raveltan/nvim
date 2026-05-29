-- phab-inline credential loading.
-- Reads ~/.config/phab-inline/creds.env (KEY=VALUE lines) and exports the
-- values into vim.env so the bundled scripts (run via vim.system) inherit
-- them. See conduit.sh: it reads PHABRICATOR_URL / PHABRICATOR_API_TOKEN,
-- falling back to ~/.arcrc when either is unset.
--
-- The file is optional: if it is missing the scripts fall back to ~/.arcrc.

local M = {}

M.creds_path = vim.fn.expand("~/.config/phab-inline/creds.env")

-- Parse a simple KEY=VALUE env file. Blank lines and # comments are ignored.
-- Surrounding single/double quotes on the value are stripped. Returns a table.
local function parse(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local env = {}
  for line in fd:lines() do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local key, val = line:match("^([%w_]+)%s*=%s*(.*)$")
      if key then
        val = val:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        env[key] = val
      end
    end
  end
  fd:close()
  return env
end

-- Load creds from the $HOME config file into vim.env. Existing env vars win
-- (an explicitly-exported shell var is not overwritten). No-op if the file is
-- absent or unreadable.
function M.load()
  local env = parse(M.creds_path)
  if not env then return false end
  for key, val in pairs(env) do
    if vim.env[key] == nil or vim.env[key] == "" then
      vim.env[key] = val
    end
  end
  return true
end

return M
