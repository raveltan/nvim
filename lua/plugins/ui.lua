return {
  -- Colorscheme
  {
    "WTFox/luna.nvim",
    name = "luna",
    priority = 1000,
    lazy = false,
    config = function()
      -- Transparent mode clears every background luna would paint, including
      -- NormalFloat — so unlike moonfly (which kept a grey13 float surface of its
      -- own) the float surface below has to be put back explicitly. Transparent
      -- editor, solid floats: a see-through hover/picker renders on top of live
      -- buffer text and is unreadable.
      require("luna").setup({ transparent = true })

      -- luna's own palette (lua/luna/palette.lua): bg_soft for the float surface,
      -- one step up for chrome that sits flush against buffer text, border for
      -- separators, comment for dimmed text.
      local float_bg = "#1f1f1f"
      local context_bg = "#262626"
      local border = "#404040"
      local dim = "#7c7c7c"

      local function overrides()
        -- Belt-and-suspenders: force-clear backgrounds on groups the theme's own
        -- transparency may leave opaque (statusline, separators). NormalFloat is
        -- deliberately NOT here — see the surface note above.
        local transparent_groups = {
          "Normal",
          "NormalNC",
          "SignColumn",
          "StatusLine",
          "StatusLineNC",
          "WinSeparator",
        }
        -- link=false is load-bearing: nvim_get_hl on a linked group returns
        -- { link = "Target" }, and nvim_set_hl ignores every other attribute when a
        -- link is present, so bg="NONE" was silently dropped. Resolving the link
        -- first returns the target's real attributes and breaks the link on write.
        for _, group in ipairs(transparent_groups) do
          local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
          hl.bg = "NONE"
          vim.api.nvim_set_hl(0, group, hl)
        end

        -- luna leaves WinSeparator's line char at #1c1c1c, 28/255 from Ghostty's
        -- black — the split boundary vanished. The theme's own border color is
        -- what FloatBorder uses, so borders and splits now read alike.
        vim.api.nvim_set_hl(0, "WinSeparator", { bg = "NONE", fg = border })

        -- Contrast fixes measured against the actual terminal background (Ghostty
        -- is #000000): luna ships ColorColumn at #000000, i.e. invisible once
        -- Normal is bg=NONE. It must also clear CursorLine (#212121) or the rule
        -- disappears on the cursor's own line, which is the line you are usually
        -- measuring.
        vim.api.nvim_set_hl(0, "ColorColumn", { bg = context_bg })
        -- The sticky context reads as a pinned panel on surface alone — one step
        -- above the float surface, since it sits directly against buffer text with
        -- no border or gap to separate it (nvim-treesitter-context renders into a
        -- plain float and has no padding option).
        vim.api.nvim_set_hl(0, "TreesitterContext", { bg = context_bg })
        vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", { bg = context_bg, fg = dim })
        -- render.lua:528 underlines the last context row via
        -- TreesitterContextBottom unconditionally — dropping `separator` did not
        -- remove it, and an unhonoured sp drew it in Normal's near-white. Surface
        -- only, no underline.
        vim.api.nvim_set_hl(0, "TreesitterContextBottom", { bg = context_bg })
        vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", { bg = context_bg, fg = dim })
        -- Inlay hints read as annotations, not boxed text.
        vim.api.nvim_set_hl(0, "LspInlayHint", { bg = "NONE", fg = dim, italic = true })

        -- Per-window winbar (lualine `winbar`, below). No surface: a filled strip
        -- read as a bar welded across every window and merged into the sticky
        -- context rendering immediately below it. Transparent, like the editor;
        -- the label separates from code by being dimmer than Normal instead of by
        -- sitting on a box. The components below clear their own bg too, since
        -- lualine paints a section background by default.
        vim.api.nvim_set_hl(0, "WinBar", { bg = "NONE", fg = "#c7c7c7" })
        vim.api.nvim_set_hl(0, "WinBarNC", { bg = "NONE", fg = dim })

        -- The float surface, plus flush chrome. Borders keep their cell (the
        -- padding is what makes a float readable over code) but are painted in the
        -- surface color, so no frame is drawn. FloatBorderTransparent is the group
        -- snacks/telescope/fzf/notify/dap-ui/mini resolve through; without it they
        -- wear a see-through ring around a solid body.
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = float_bg, fg = "#e4e4e8" })
        vim.api.nvim_set_hl(0, "FloatBorder", { bg = float_bg, fg = float_bg })
        vim.api.nvim_set_hl(0, "FloatBorderTransparent", { bg = float_bg, fg = float_bg })
        vim.api.nvim_set_hl(0, "FloatTitle", { bg = float_bg, fg = "#c7c7c7" })

        -- Snacks picker chrome. The flush-border trick above assumes the float
        -- BODY is float_bg; that holds for anything using NormalFloat (hover,
        -- blink, which-key) but every snacks picker window resolves its body
        -- through SnacksPicker -> Normal, whose bg the transparency loop at the
        -- top of this function clears. So the picker drew an opaque ring around a
        -- see-through body — the frame the flush borders exist to avoid,
        -- inverted. Three links fix the whole surface, because snacks routes
        -- list/preview/input/box through these:
        --   SnacksPicker       body for all four windows
        --   *InputBorder       the one border that does NOT go through
        --                      SnacksPickerBorder, so the prompt alone wore a
        --                      differently-colored frame
        --   SnacksPickerTitle  links to Dimmed (bg NONE) while the matching
        --                      footer already sits on the float surface
        -- All snacks hl groups are registered with default=true, so these
        -- explicit definitions win regardless of load order.
        vim.api.nvim_set_hl(0, "SnacksPicker", { link = "NormalFloat" })
        vim.api.nvim_set_hl(0, "SnacksPickerInputBorder", { link = "SnacksPickerBorder" })
        vim.api.nvim_set_hl(0, "SnacksPickerTitle", { link = "FloatTitle" })
      end

      vim.cmd.colorscheme("luna")
      overrides()
      -- Anything that re-runs the colorscheme (a :colorscheme luna, a plugin
      -- reload) restores luna's own definitions and drops all of the above.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("luna_overrides", { clear = true }),
        pattern = "luna",
        callback = overrides,
      })
    end,
  },

  -- Icons
  {
    "echasnovski/mini.icons",
    lazy = true,
    config = true,
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "echasnovski/mini.icons",
      -- showtabline=0 + harpoon meant the marks were invisible everywhere; this
      -- renders them in the statusline instead of reintroducing a tabline.
      { "letieu/harpoon-lualine", dependencies = { "ThePrimeagen/harpoon" } },
    },
    opts = function()
      local macro = {
        function()
          local r = vim.fn.reg_recording()
          return r ~= "" and ("REC @" .. r) or ""
        end,
        cond = function() return vim.fn.reg_recording() ~= "" end,
        color = { fg = "#ff5555", gui = "bold" },
      }

      local lsp = {
        function()
          local cs = vim.lsp.get_clients({ bufnr = 0 })
          if #cs == 0 then return "" end
          local names = {}
          for _, c in ipairs(cs) do table.insert(names, c.name) end
          return " " .. table.concat(names, ",")
        end,
      }

      -- Pending plugin updates, hidden when there are none.
      local lazy_updates = {
        function() return "󰚰 " .. require("lazy.status").updates() end,
        cond = function() return require("lazy.status").has_updates() end,
        color = { fg = "#d9a35a" }, -- luna warning
      }

      -- Show encoding/fileformat only when non-default
      local encoding = {
        "encoding",
        cond = function() return (vim.bo.fileencoding or "") ~= "" and vim.bo.fileencoding ~= "utf-8" end,
      }
      local fileformat = {
        "fileformat",
        cond = function() return vim.bo.fileformat ~= "unix" end,
      }

      -- Directory of the current file, dimmed. The winbar carries the bare
      -- filename per window, so the only thing left worth showing globally is
      -- "which tree am I in" when several repos are open across tabs.
      local dirname = {
        function()
          local d = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":~:.")
          return (d == "" or d == ".") and "" or d
        end,
        cond = function() return vim.bo.buftype == "" and vim.fn.expand("%") ~= "" end,
        color = { fg = "#888888" }, -- luna grey
      }

      -- Live debug session state ("Running", "Stopped at ..."). package.loaded
      -- guard keeps a statusline redraw from force-loading nvim-dap.
      local dap_status = {
        function()
          local s = require("dap").status()
          return "  " .. (#s > 30 and (s:sub(1, 29) .. "…") or s)
        end,
        cond = function()
          return package.loaded["dap"] ~= nil and require("dap").status() ~= ""
        end,
        color = { fg = "#d9a35a" }, -- luna warning
      }

      -- Neotest results for the *current buffer* only, so the counts always
      -- refer to the file under the cursor rather than the whole session.
      -- status_counts walks the adapter's position tree, and the three
      -- components below each hit it twice (cond + render). Memoised for 250ms
      -- so one redraw costs one walk instead of six.
      local nt_cache, nt_at, nt_buf = nil, 0, -1
      local function neotest_counts()
        if not package.loaded["neotest"] then return nil end
        local buf, now = vim.api.nvim_get_current_buf(), vim.uv.hrtime()
        if buf == nt_buf and nt_at ~= 0 and now - nt_at < 250e6 then return nt_cache end
        nt_buf, nt_at = buf, now
        nt_cache = nil
        local ok, acc = pcall(function()
          local state = require("neotest").state
          local a = { passed = 0, failed = 0, running = 0 }
          for _, id in ipairs(state.adapter_ids()) do
            local c = state.status_counts(id, { buffer = 0 })
            if c then
              a.passed, a.failed, a.running = a.passed + c.passed, a.failed + c.failed, a.running + c.running
            end
          end
          return a
        end)
        nt_cache = ok and acc or nil
        return nt_cache
      end

      -- Split into three components so each keeps its own colour; a single
      -- component would need inline %#hl# escapes that bleed into the next one.
      local function neotest_part(key, icon, fg)
        return {
          function()
            local c = neotest_counts()
            return icon .. " " .. (c and c[key] or 0)
          end,
          cond = function()
            local c = neotest_counts()
            return c ~= nil and c[key] > 0
          end,
          color = { fg = fg },
          padding = { left = 1, right = 0 },
        }
      end

      -- bg=NONE on both components is load-bearing, not decoration: lualine
      -- paints its section background (grey07) behind everything it renders, so
      -- clearing WinBar/WinBarNC alone would still leave the label in a dark
      -- notch. These have to match the two groups set in the luna block.
      -- The icon keeps its language colour now that there is no surface for it
      -- to clash with.
      local function winbar_section(fg)
        return {
          lualine_c = {
            {
              "filetype",
              icon_only = true,
              separator = "",
              padding = { left = 1, right = 0 },
              color = { bg = "NONE" },
            },
            {
              "filename",
              path = 0,
              symbols = { modified = "  ", readonly = " ", unnamed = " " },
              color = { bg = "NONE", fg = fg },
            },
          },
        }
      end

      -- Refresh on macro start/stop. ModeChanged dropped: lualine already
      -- redraws on mode change internally, the extra refresh just doubled work
      -- on every n↔i↔v↔c transition.
      vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
        callback = function() require("lualine").refresh() end,
      })

      -- disabled_filetypes.winbar can only match a filetype, and a bare
      -- :terminal buffer has none — it was getting a winbar reading "zsh".
      -- Snacks terminals already carry snacks_terminal, so this only names the
      -- ones nothing else claimed.
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "" then vim.bo[ev.buf].filetype = "terminal" end
        end,
      })

      return {
        options = {
          -- "auto" derives the bar from the active colorscheme's highlights;
          -- lualine ships no luna theme, and the bar is transparent anyway.
          theme = "auto",
          globalstatus = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "snacks_dashboard", "starter" },
            -- Every filetype edgy docks (see edgy.lua) already draws its own
            -- titled winbar; letting lualine write one there would replace the
            -- panel title with a filename. Dashboards/pickers have no file at
            -- all, so a winbar is pure noise there.
            winbar = {
              "dashboard",
              "alpha",
              "snacks_dashboard",
              "starter",
              "snacks_terminal",
              "snacks_picker_list",
              "snacks_picker_preview",
              "trouble",
              "qf",
              "dap-repl",
              "dap-view",
              "dap-view-term",
              "grug-far",
              "undotree",
              "diff",
              "help",
              "man",
              "checkhealth",
              "neo-tree",
              "lazy",
              "mason",
              "terminal",
              "toggleterm",
            },
          },
        },
        sections = {
          lualine_a = { { "mode", icon = "" } },
          lualine_b = {
            { "branch", icon = "" },
            { "diff", symbols = { added = " ", modified = " ", removed = " " } },
            { "diagnostics", symbols = { error = " ", warn = " ", info = " ", hint = " " } },
          },
          lualine_c = {
            -- The filename lives in the per-window winbar now (see `winbar`
            -- below), which is what makes "which of these three component.ts is
            -- focused?" answerable without repeating it down here.
            dirname,
            macro,
            -- Harpoon marks: 1 2 [3] 4 — brackets mark the current file. Renders
            -- nothing when the list is empty (no_harpoon = "").
            {
              "harpoon2",
              indicators = { "1", "2", "3", "4", "5" },
              active_indicators = { "[1]", "[2]", "[3]", "[4]", "[5]" },
              _separator = " ",
              no_harpoon = "",
              color = { fg = "#75a1c7" }, -- luna blue
            },
          },
          lualine_x = {
            dap_status,
            neotest_part("failed", "", "#e08585"), -- luna error
            neotest_part("passed", "", "#6fbe80"), -- luna ok
            neotest_part("running", "", "#75a1c7"), -- luna blue
            lazy_updates,
            lsp,
            encoding,
            fileformat,
          },
          -- 'showcmdloc' is "statusline" (lua/config/options.lua); a component
          -- whose string starts with % is loaded as a raw statusline expression,
          -- so this is where the pending-key display lands.
          lualine_y = { { "%S" }, "progress" },
          lualine_z = { { "location", icon = "" } },
        },
        -- One bar per window, carrying only what identifies that window: type
        -- icon, bare filename, modified/readonly marker. Everything positional
        -- or global stays in the single statusline below it.
        winbar = winbar_section("#9e9e9e"),
        inactive_winbar = winbar_section("#6d6d6d"),
        extensions = { "lazy", "mason", "neo-tree", "trouble", "quickfix" },
      }
    end,
  },

  -- Indent guides + current-scope line come from snacks.indent/snacks.scope
  -- (snacks.lua); mini.indentscope was removed — it drew the scope line a
  -- second time on every buffer.

  -- Rainbow brackets via Treesitter
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      require("rainbow-delimiters.setup").setup({
        -- Size guard: skip attach for files >1500 lines (checked at FileType attach time)
        condition = function(buf)
          return vim.api.nvim_buf_line_count(buf) <= 1500
        end,
      })
    end,
  },

  -- Inline color swatches for hex, rgb, hsl
  -- (catgoose fork — NvChad's repo was transferred here; it's the maintained one)
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPost",
    opts = {
      user_default_options = {
        css = true,
        tailwind = true,
        mode = "virtualtext",
      },
    },
  },

  -- Decorated scrollbar (diagnostics, git hunks, marks, search, cursor)
  {
    "lewis6991/satellite.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      current_only = true,
      winblend = 50,
      zindex = 40,
      excluded_filetypes = {
        "dashboard", "snacks_dashboard", "alpha", "starter",
        "help", "lazy", "mason", "TelescopeResults", "TelescopePrompt",
        "trouble", "Trouble", "oil", "undotree", "diff",
        "dap-view", "dap-view-term", "dap-repl",
        "noice", "checkhealth", "qf", "grug-far",
        "fugitive", "fugitiveblame", "git",
        "Avante",
      },
      handlers = {
        cursor      = { enable = true, overlap = true, priority = 1000 },
        search      = { enable = true, overlap = true, priority = 10 },
        diagnostic  = { enable = true, signs = { "-", "=", "≡" }, min_severity = vim.diagnostic.severity.WARN },
        gitsigns    = { enable = true, signs = { add = "│", change = "│", delete = "-" } },
        marks       = { enable = true, show_builtins = false, key = "m" },
        quickfix    = { enable = true, signs = { "-", "=", "≡" } },
      },
    },
    config = function(_, opts)
      require("satellite").setup(opts)
      -- Match transparent theme
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "SatelliteBar", { bg = "#30363d" })
          vim.api.nvim_set_hl(0, "SatelliteBackground", { bg = "NONE" })
        end,
      })
      pcall(function()
        vim.api.nvim_set_hl(0, "SatelliteBar", { bg = "#30363d" })
        vim.api.nvim_set_hl(0, "SatelliteBackground", { bg = "NONE" })
      end)
    end,
  },

  -- Colored function arguments via Treesitter
  {
    "m-demare/hlargs.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("hlargs").setup()
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
          if vim.api.nvim_buf_line_count(args.buf) > 1500 then
            require("hlargs").disable_buf(args.buf)
          end
        end,
      })
    end,
  },

  -- Wandering duck (:DuckHatch / :DuckCook)
  {
    "tamton-aquib/duck.nvim",
    cmd = { "DuckHatch", "DuckCook", "DuckKill", "DuckCookAll", "DuckKillAll" },
    keys = {
      -- winborder=rounded is global; temp-disable so duck floats spawn borderless
      { "<leader>udd", function()
          local p = vim.o.winborder; vim.o.winborder = "none"
          require("duck").hatch(); vim.o.winborder = p
        end, desc = "Hatch duck" },
      { "<leader>udk", function() require("duck").cook() end, desc = "Cook one duck" },
      { "<leader>uda", function()
          local p = vim.o.winborder; vim.o.winborder = "none"
          require("duck").hatch("🦆", 10); vim.o.winborder = p
        end, desc = "Hatch fast duck" },
      { "<leader>udK", function() require("duck").cook_all() end, desc = "Cook all ducks" },
    },
  },

  -- UI polish
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = {
      cmdline = {
        view = "cmdline", -- use inline cmdline to avoid E11 split errors in command-line window
      },
      lsp = {
        -- silent: noice's hover is a per-client handler (noice/lsp/hover.lua) run
        -- once per client via buf_request. On multi-client buffers (TS attaches
        -- typos_lsp + tailwindcss alongside vtsls) any client with no
        -- hover at the cursor fires `vim.notify("No information available")` even
        -- when another client returns real hover. Suppress that spurious notify.
        hover = { enabled = true, silent = true },
        signature = { enabled = false }, -- blink.cmp handles signature help
        message = { enabled = true },
        progress = { enabled = false },  -- fidget.nvim owns LSP progress
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      views = {
        -- Override noice default hover view (max_height=20, no border) which
        -- otherwise truncates long TypeScript signatures and shows '@@@' tail.
        hover = {
          size = { max_height = 40, max_width = 180 },
          border = { style = "rounded", padding = { 0, 1 } },
        },
      },
      presets = {
        long_message_to_split = true,
        -- Borders + FloatBorder:DiagnosticInfo on the hover/signature doc views,
        -- so LSP docs read as a distinct surface against the transparent bg.
        -- (views.hover above still wins on size — presets merge first.)
        lsp_doc_border = true,
        -- inc_rename is deliberately NOT enabled: that preset only styles the
        -- :IncRename cmdline, and inc-rename.nvim is not installed (rename goes
        -- through lua/config/rename.lua + snacks.rename).
      },
    },
  },

  -- Comfy line numbers: relative numbers using only easy-to-reach digits (1-5)
  {
    "mluders/comfy-line-numbers.nvim",
    event = "BufReadPre",
    opts = {
      labels = {
        "1", "2", "3", "4", "5", "11", "12", "13", "14", "15",
        "21", "22", "23", "24", "25", "31", "32", "33", "34", "35",
        "41", "42", "43", "44", "45", "51", "52", "53", "54", "55",
        "111", "112", "113", "114", "115", "121", "122", "123", "124", "125",
        "131", "132", "133", "134", "135", "141", "142", "143", "144", "145",
        "151", "152", "153", "154", "155",
      },
      up_key = "k",
      down_key = "j",
      hidden_file_types = { "undotree" },
      hidden_buffer_types = { "terminal", "nofile" },
    },
  },
}
