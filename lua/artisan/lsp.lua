-- LSP deltas for Laravel projects. Consumed by lua/plugins/lsp.lua, which owns
-- the actual vim.lsp.config() calls — this module only supplies the data, so
-- there is still exactly one place where each server is configured.
local M = {}

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
