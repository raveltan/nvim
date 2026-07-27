-- LSP deltas for Laravel projects. Consumed by lua/plugins/lsp.lua, which owns
-- the actual vim.lsp.config() calls — this module only supplies the data, so
-- there is still exactly one place where each server is configured.
local M = {}

-- intelephense's `stubs` setting REPLACES its default list rather than adding
-- to it, so the defaults have to be repeated verbatim. Everything after the
-- blank-line comment is the Laravel-specific addition: these extensions are
-- what a real app talks to (queues, cache, image processing) and without their
-- stubs intelephense reports every Redis:: / Imagick call as undefined.
-- Unknown stub names are ignored by the server, so listing an extension the
-- installed PHP doesn't have is harmless.
local STUBS = {
  "apache", "bcmath", "bz2", "calendar", "com_dotnet", "Core", "ctype", "curl",
  "date", "dba", "dom", "enchant", "exif", "FFI", "fileinfo", "filter", "fpm",
  "ftp", "gd", "gettext", "gmp", "hash", "iconv", "imap", "intl", "json",
  "ldap", "libxml", "mbstring", "meta", "mysqli", "oci8", "odbc", "openssl",
  "pcntl", "pcre", "PDO", "pdo_ibm", "pdo_mysql", "pdo_pgsql", "pdo_sqlite",
  "pgsql", "Phar", "posix", "pspell", "readline", "Reflection", "session",
  "shmop", "SimpleXML", "snmp", "soap", "sockets", "sodium", "SPL", "sqlite3",
  "standard", "superglobals", "sysvmsg", "sysvsem", "sysvshm", "tidy",
  "tokenizer", "xml", "xmlreader", "xmlrpc", "xmlwriter", "xsl",
  "Zend OPcache", "zip", "zlib",

  "redis", "memcached", "imagick", "pcov", "xdebug", "swoole", "mongodb",
  "amqp", "yaml", "ds", "igbinary",
}

-- Generated/compiled trees that would otherwise be indexed as real source.
-- storage/ is already excluded by the base config in plugins/lsp.lua; these are
-- the Laravel-shaped additions. NOT excluded on purpose: _ide_helper*.php and
-- .phpstorm.meta.php in the project root — those files exist precisely so
-- intelephense can resolve facades and container bindings.
local EXCLUDES = {
  "**/bootstrap/cache/**",
  "**/public/build/**",
  "**/public/hot",
  "**/.phpunit.cache/**",
}

---@return string[]
function M.stubs()
  return vim.deepcopy(STUBS)
end

---@return string[]
function M.excludes()
  return vim.deepcopy(EXCLUDES)
end

-- Filetypes that need to be added to the html/emmet/tailwind servers so blade
-- buffers get tag, abbreviation and class completion. intelephense is
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
