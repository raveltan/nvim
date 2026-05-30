-- blink.cmp source for the Chrome DevTools console input (util.webconsole).
--
-- Bridges blink.cmp's async completion protocol to webconsole's
-- M.complete_async, which talks to the Go bridge over the shared connection.
-- It is inert in every buffer except the console input: enabled() gates on the
-- buffer-local marker `vim.b.webconsole_input` set by webconsole's ensure_bufs.
--
-- Register as a blink.cmp provider with module = "util.cmp_webconsole".
--
-- blink.cmp v1.x source provider protocol: new/enabled/get_trigger_characters/
-- get_completions(ctx, callback) -> cancel_fn. Everything heavy (webconsole,
-- blink types) is required lazily so this module loads with no dependencies.

local source = {}

function source.new(opts)
  return setmetatable({}, { __index = source })
end

-- cheap: just the buffer var, so the source is dormant in all other buffers.
function source:enabled()
  return vim.b.webconsole_input == true
end

function source:get_trigger_characters()
  return { "." }
end

function source:get_completions(ctx, callback)
  local line = ctx and ctx.line or vim.api.nvim_get_current_line()
  local col0 = (ctx and ctx.cursor and ctx.cursor[2]) or vim.api.nvim_win_get_cursor(0)[2]

  local function done(items)
    -- blink may call this off the main loop; schedule to be safe.
    vim.schedule(function()
      callback({
        is_incomplete_backward = false,
        is_incomplete_forward = false,
        items = items,
      })
    end)
  end

  local ok, wc = pcall(require, "util.webconsole")
  if not ok then
    done({})
    return function() end
  end

  -- Property kind (10) per LSP. Resolve defensively so a missing/renamed blink
  -- types module never errors the source.
  local kind = 10
  local kok, types = pcall(require, "blink.cmp.types")
  if kok and types and types.CompletionItemKind and types.CompletionItemKind.Property then
    kind = types.CompletionItemKind.Property
  end

  wc.complete_async(line, col0, function(names)
    local items = {}
    for _, n in ipairs(names or {}) do
      items[#items + 1] = { label = n, insertText = n, kind = kind }
    end
    done(items)
  end)

  return function() end
end

return source
