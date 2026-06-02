local M = {}

-- Jump to the next/prev occurrence of the word under the cursor via plain text
-- search (no LSP). Sets the `/` register (whole-word, `\V` so symbols stay
-- literal, `\C` to force case-sensitive regardless of ignorecase/smartcase) +
-- hlsearch, then feeds n/N so the centered+hlslens maps in config/keymaps.lua
-- fire and `n`/`N` keep cycling afterwards.
--   next_key: "n" (forward) or "N" (backward)
function M.search_cword(next_key)
  local w = vim.fn.expand("<cword>")
  if w == "" then return end
  vim.fn.setreg("/", [[\C\V\<]] .. vim.fn.escape(w, [[\]]) .. [[\>]])
  vim.opt.hlsearch = true
  vim.api.nvim_feedkeys(next_key, "m", false)
end

return M
