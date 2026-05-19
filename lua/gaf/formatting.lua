local paths = require("gaf.paths")

local M = {}

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
    stdin = false,
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
