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

-- laravel-lsp is a Composer-installed PHP script whose PHAR declares a hard
-- `^8.2.0` requirement: launched by anything older it prints Box's requirements
-- report and exits 1 *before* the LSP handshake, so the client dies with
-- "quit with exit code 1" and the server appears to simply not work. `php` on
-- PATH is 8.1 here, so the server is handed an interpreter explicitly rather
-- than inheriting whatever the shell resolves.
--
-- Versions are read from the resolved Homebrew Cellar path
-- (/opt/homebrew/opt/php@8.4/bin/php → .../Cellar/php@8.4/8.4.22/bin/php)
-- instead of by running each candidate: this is consulted while the LSP configs
-- are registered, on the first buffer of the session, where a spawn per
-- candidate would be a visible cost.
---@return string|nil php absolute path to a php >= 8.2, nil if none is installed
function M.php_82()
	local best, best_ver
	local function consider(path)
		if path == "" or vim.fn.executable(path) ~= 1 then return end
		local major, minor = vim.fn.resolve(path):match("/(%d+)%.(%d+)%.%d+/bin/php$")
		if not major then return end
		local ver = tonumber(major) * 100 + tonumber(minor)
		if ver >= 802 and (not best_ver or ver > best_ver) then best, best_ver = path, ver end
	end
	consider(vim.fn.exepath("php"))
	-- Both formula shapes: `php` (current) and the versioned `php@8.4` kegs.
	for _, glob in ipairs({ "/opt/homebrew/opt/php/bin/php", "/opt/homebrew/opt/php@*/bin/php" }) do
		for _, path in ipairs(vim.fn.glob(glob, false, true)) do consider(path) end
	end
	return best
end

return M
