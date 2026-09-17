-- Shared notification + progress helpers.
--
-- Every user-visible message from this module goes through notify() so the
-- snacks notifier groups them under one title. Long-running conduit calls
-- report through fidget instead: a spinner in the corner, not a notification
-- per fetch. fidget loads on LspAttach, so it may not be around yet in a
-- fresh buffer -- the pcall keeps the fetch working either way.

local M = {}

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Phabricator" })
end

local noop = function() end

-- Returns a handle with :finish(msg) and :fail(msg). Safe to call from any
-- context; the fidget calls themselves are scheduled onto the main loop.
function M.progress(title, message)
  local ok, fidget = pcall(require, "fidget.progress")
  if not ok then
    return { finish = noop, fail = function(msg) M.notify(msg or "failed", vim.log.levels.WARN) end }
  end
  local handle = fidget.handle.create({
    title = title,
    message = message,
    -- fidget groups by client name; "phab" keeps these out of the LSP rows.
    lsp_client = { name = "phab" },
  })
  return {
    finish = function(msg)
      vim.schedule(function()
        if msg then handle.message = msg end
        handle:finish()
      end)
    end,
    fail = function(msg)
      vim.schedule(function()
        handle.message = msg or "failed"
        handle:cancel()
      end)
    end,
  }
end

return M
