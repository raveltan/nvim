-- Oh My Pi bridge. Two halves: this plugin broadcasts the active file, cursor
-- line and visual range (`src/a.ts:42`, `src/a.ts:40-50`) over a libuv Unix
-- socket; the omp extension (`omp plugin install omp.nvim`, already installed)
-- listens on $TMPDIR/omp-nvim-sockets and injects that as passive context into
-- every prompt. Sessions are matched by cwd, so omp has to be started from the
-- same directory nvim is in -- which the <leader>ao terminal below guarantees.
-- setup() takes no options. `:checkhealth omp` shows socket + watcher state.
return {
  {
    "rauls-kjarners/omp.nvim",
    event = "VeryLazy",
    config = function()
      require("omp").setup()
    end,
    keys = {
      {
        "<leader>ao",
        function()
          -- Right-docked so it sits beside code rather than under it like the
          -- <leader>/ shell. Same toggle semantics: one instance, hide/show.
          Snacks.terminal.toggle("omp", { win = { position = "right", width = 0.4 } })
        end,
        desc = "Toggle Oh My Pi",
      },
    },
  },
}
