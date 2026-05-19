-- Coverage gutter signs + summary. Reads:
--   PHP:  coverage/cobertura.xml         (PHPUnit --coverage-cobertura)
--   Ruby: coverage/.resultset.json       (SimpleCov default)
return {
  {
    "andythigpen/nvim-coverage",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "Coverage",
      "CoverageLoad",
      "CoverageLoadLcov",
      "CoverageShow",
      "CoverageHide",
      "CoverageToggle",
      "CoverageClear",
      "CoverageSummary",
    },
    keys = {
      { "<leader>tv", "<cmd>Coverage<cr>", desc = "Coverage signs" },
      { "<leader>tV", "<cmd>CoverageSummary<cr>", desc = "Coverage summary" },
    },
    -- Cobertura parser (used for PHP) requires lua-xmlreader. Homebrew Lua 5.5
    -- can't build that rock (luaL_checkint/luaL_register removed in 5.3/5.2),
    -- so install against Lua 5.1 — LuaJIT is 5.1-ABI compatible:
    --   brew install lua@5.1
    --   luarocks --lua-version=5.1 --lua-dir="$(brew --prefix lua@5.1)" \
    --       install --local lua-xmlreader
    -- Extend LuaJIT's package paths so require("xmlreader") finds it.
    init = function()
      local home = os.getenv("HOME") or ""
      local rocks_lib = home .. "/.luarocks/lib/lua/5.1/?.so"
      local rocks_share = home .. "/.luarocks/share/lua/5.1/?.lua"
      if not package.cpath:find(rocks_lib, 1, true) then
        package.cpath = package.cpath .. ";" .. rocks_lib
      end
      if not package.path:find(rocks_share, 1, true) then
        package.path = package.path .. ";" .. rocks_share
      end
    end,
    opts = {
      auto_reload = true,
      lang = {
        php = {
          coverage_file = "coverage/cobertura.xml",
        },
        -- ruby: leave default (coverage/.resultset.json from SimpleCov)
      },
    },
  },
}
