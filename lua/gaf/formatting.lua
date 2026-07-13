local paths = require("gaf.paths")

local M = {}

-- Partial override, merged over conform's builtin php_cs_fixer (inherit=true
-- default): stdin=false and the rest come from the builtin; only the fl-gaf
-- binary and --config differ. args stays explicit because the options must
-- follow the `fix` subcommand (prepend_args would put them before it).
function M.php_cs_fixer_formatter()
  return {
    command = paths.fl_gaf .. "/support/php-cs-fixer/vendor/bin/php-cs-fixer",
    args = {
      "fix",
      "--config=" .. paths.fl_gaf .. "/.php-cs-fixer.dist.php",
      "--no-interaction",
      "--quiet",
      "$FILENAME",
    },
  }
end

function M.phpcs_args()
  return {
    "-q",
    "--report=json",
    "--standard=" .. paths.fl_gaf .. "/phpcs_gaf.xml",
    "-",
  }
end

return M
