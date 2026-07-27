-- Blade's own comment form. Neovim ships no ftplugin for `blade` (only the
-- filetype detection), so without this `gcc` had nothing to work with —
-- commentstring was empty and comments silently did nothing.
--
-- ts-comments.nvim (plugins/editor.lua) swaps this out per treesitter language,
-- so `//` is still used inside @php blocks and injected <script> regions; this
-- is the markup-level default.
vim.bo.commentstring = "{{-- %s --}}"
