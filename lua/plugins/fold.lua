-- Folding: nvim-ufo drives folds (LSP foldingRange → treesitter fallback) and
-- gives a peek window (see folded body without opening it) plus a pretty,
-- syntax-highlighted foldtext with a trailing line count.
--
-- Why ufo over plain `vim.treesitter.foldexpr`:
--   * LSP folds are semantic — import blocks, #region markers, multiline
--     comments fold as units that treesitter's fold query misses.
--   * peekFoldedLinesUnderCursor() previews a closed fold in a float (K).
--   * fold_virt_text_handler renders the first line with real highlights.
--
-- ufo OWNS folding: it sets foldmethod=manual and applies folds itself. The
-- old `foldmethod=expr` / `foldexpr` wiring was removed from the treesitter
-- FileType autocmd (lua/plugins/treesitter.lua) so the two don't fight.
-- foldlevel/foldlevelstart/foldenable/foldcolumn stay in lua/config/options.lua.
--
-- Load order: foldingRange capability is advertised to servers in
-- lua/plugins/lsp.lua (blink capabilities + textDocument.foldingRange).
return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      -- zR/zM/zr/zm go through ufo so they honor LSP/treesitter fold kinds
      -- (native zr/zm only nudge foldlevel; ufo's also respect kind ordering).
      { "zR", function() require("ufo").openAllFolds() end, desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "Close all folds" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end, desc = "Open folds (raise level)" },
      { "zm", function() require("ufo").closeFoldsWith() end, desc = "Close folds (lower level)" },
      -- Fold TO an absolute level: keep everything ≤ N open, fold the rest.
      -- foldlevel works on ufo's manual folds, so e.g. z1 in a class keeps the
      -- class open and folds every method body inside it.
      { "z1", function() vim.wo.foldlevel = 1 end, desc = "Fold to level 1" },
      { "z2", function() vim.wo.foldlevel = 2 end, desc = "Fold to level 2" },
      { "z3", function() vim.wo.foldlevel = 3 end, desc = "Fold to level 3" },
      { "z4", function() vim.wo.foldlevel = 4 end, desc = "Fold to level 4" },
      { "z5", function() vim.wo.foldlevel = 5 end, desc = "Fold to level 5" },
      -- Jump between closed folds.
      { "]z", function() require("ufo").goNextClosedFold() end, desc = "Next closed fold" },
      { "[z", function() require("ufo").goPreviousClosedFold() end, desc = "Prev closed fold" },
      -- Peek the fold under the cursor in a float (also wired onto K with a
      -- hover fallback in lua/config/keymaps.lua).
      { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Peek folded lines" },
    },
    opts = {
      open_fold_hl_timeout = 150,
      -- Provider chain per buffer. Skip special buffers and very large files
      -- (mirrors the treesitter perf guard so generated/minified files stay fast).
      provider_selector = function(bufnr, _filetype, buftype)
        if buftype ~= "" then return "" end
        if vim.api.nvim_buf_line_count(bufnr) > 10000 then return "" end
        return { "lsp", "treesitter" }
      end,
      preview = {
        win_config = {
          border = "rounded",
          winblend = 0,
          winhighlight = "Normal:Normal",
          maxheight = 20,
        },
        mappings = {
          scrollU = "<C-u>",
          scrollD = "<C-d>",
          jumpTop = "[",
          jumpBot = "]",
          close = "q",
        },
      },
      -- Foldtext: first line with real syntax highlights + "󰁂 N lines" suffix,
      -- matching the look of the old custom foldtext (Folded hl, same glyph).
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("  󰁂 %d lines"):format(endLnum - lnum + 1)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- truncate() may return fewer cells than asked; pad so the suffix aligns.
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "Folded" })
        return newVirtText
      end,
    },
  },
}
