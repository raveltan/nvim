-- LSP deltas for Laravel projects. Consumed by lua/plugins/lsp.lua, which owns
-- the actual vim.lsp.config() calls — this module only supplies the data, so
-- there is still exactly one place where each server is configured.
local M = {}

-- No stub or exclude lists here anymore. They existed for intelephense, which
-- needed the whole phpstorm-stubs set repeated verbatim to add `redis`/`imagick`
-- to it, plus a glob list to keep bootstrap/cache and public/build out of the
-- index. phpantom_lsp compiles the stubs into the binary and honours .gitignore,
-- so both are the server's problem now; anything left to tune goes in the
-- project's `.phpantom.toml` (see lua/plugins/lsp.lua).

-- Filetypes that need to be added to the html/emmet/tailwind servers so blade
-- buffers get tag, abbreviation and class completion. The PHP server is
-- intentionally NOT in this list: it cannot parse @directives, so attaching it
-- to blade trades a little completion inside {{ }} for a syntax error on every
-- @if. Blade's PHP intelligence comes from laravel.nvim and blade-nav instead.
M.blade_filetypes = { "blade" }

-- Extra class-extraction patterns for tailwindcss-language-server so it also
-- offers completion (and hover/lint) in the places Blade and Livewire put
-- classes, none of which look like `class="…"` to the default matcher. Plain
-- `class="…"` needs nothing — it's in the server's default classAttributes.
--
-- These are JavaScript regexes evaluated inside the language server, not Lua
-- patterns, hence the doubled backslashes. A two-element entry is
-- {container, inner}: match the container first, then pull classes out of it.
M.tailwind_class_regex = {
  -- @class([ 'p-4' => $cond, 'font-bold' ])
  { "@class\\(\\[([^\\]]*)\\]\\)", "'([^']*)'" },
  -- Livewire's conditional class swaps
  "wire:loading\\.class(?:\\.remove)?=[\"']([^\"']*)",
  -- Alpine bindings, both spellings
  "x-bind:class=[\"']([^\"']*)",
  ":class=[\"']([^\"']*)",
}

return M
