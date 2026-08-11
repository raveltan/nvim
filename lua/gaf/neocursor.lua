-- Opt-in switch for neocursor.nvim (Cursor Tab). The plugin stays unloaded until
-- this module enables it, so a normal session has no sidecar process, no ghost
-- text and no backend notifications at all.
--
-- neocursor has no enable/disable of its own: setup() launches the sidecar and
-- owns the "neocursor" augroup plus its insert-mode maps, while stop() only kills
-- the job and leaves the autocmds firing requests into a dead pipe. Disabling
-- therefore has to undo all of it by hand; enabling again is another setup() with
-- the same opts, cached from the plugin spec on the first activate.
local M = {}

local enabled = false
local opts = nil

-- handle_result() notifies at WARN for every backend error, and requests fire per
-- keystroke — one expired Cursor session repeats the identical line dozens of
-- times while typing. Collapse repeats of the same neocursor message to one per
-- minute; the unthrottled history stays in :NeocursorLog / :NeocursorDebug.
local THROTTLE_SECS = 60
local notify_wrapped = false
local last_notified = {}

local function throttle_notifications()
  if notify_wrapped then return end
  notify_wrapped = true
  -- Captured, not looked up per call: snacks/noice have both already installed
  -- their vim.notify by the time the first enable happens (VeryLazy < keypress).
  local inner = vim.notify
  vim.notify = function(msg, level, notify_opts)
    if type(msg) == "string" and msg:find("^neocursor:") then
      local seen = last_notified[msg]
      if seen and os.time() - seen < THROTTLE_SECS then return end
      last_notified[msg] = os.time()
    end
    return inner(msg, level, notify_opts)
  end
end

-- The key setup() maps for accept_partial (opts.map_partial: false disables it,
-- true or nil means the plugin's own <M-Right> default).
local function partial_key()
  local key = opts and opts.map_partial
  if key == false then return nil end
  return type(key) == "string" and key or "<M-Right>"
end

function M.enabled() return enabled end

-- Entry point for the plugin spec's config: runs on the lazy load that enable()
-- triggers, and directly on every re-enable after that.
function M.activate(spec_opts)
  opts = spec_opts or opts or {}
  throttle_notifications()
  require("neocursor").setup(opts)
  enabled = true
end

function M.enable()
  if enabled then return end
  if package.loaded["neocursor"] then
    M.activate(opts)
  else
    require("lazy").load({ plugins = { "neocursor.nvim" } }) -- config -> M.activate
  end
end

function M.disable()
  enabled = false
  local neocursor = package.loaded["neocursor"]
  if not neocursor then return end
  -- dismiss() before stop(): it is the only public way to drop the pending
  -- prediction, and leaving one behind means a <Tab> after re-enable applies an
  -- edit computed against a buffer that has since moved. The cost is a recorded
  -- rejection for a suggestion the user never actually rejected.
  neocursor.dismiss()
  neocursor.stop()
  pcall(vim.api.nvim_del_augroup_by_name, "neocursor")
  pcall(vim.keymap.del, "i", "<C-]>") -- dismiss
  local partial = partial_key()
  if partial then pcall(vim.keymap.del, "i", partial) end
  -- dismiss() only clears the current buffer; ghosts anchored in buffers left
  -- via BufLeave outlive it.
  local preview = require("neocursor.preview")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(preview.clear, buf)
      pcall(preview.clear_prediction, buf)
    end
  end
end

function M.toggle()
  if enabled then M.disable() else M.enable() end
end

return M
