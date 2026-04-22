return {
  -- Auto-detect indentation
  { "tpope/vim-sleuth", event = "BufReadPre" },

  -- Folding with treesitter + peek preview
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    opts = {
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
    },
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,               desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end,              desc = "Close all folds" },
      { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Peek fold" },
    },
  },

  -- Undo tree visualization
  {
    "mbbill/undotree",
    keys = {
      { "<leader>cu", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
    },
  },

  -- Split/join code blocks (single-line <-> multi-line)
  {
    "Wansmer/treesj",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>cj", function() require("treesj").toggle() end, desc = "Split/join block" },
    },
    opts = {
      use_default_keymaps = false,
      max_join_length = 150,
    },
  },

  -- Refactoring (extract function/variable, inline)
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>re", function() require("refactoring").select_refactor() end,            mode = "v",          desc = "Refactor (select)" },
      { "<leader>rf", function() require("refactoring").refactor("Extract Function") end, mode = "v",          desc = "Extract function" },
      { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, mode = "v",          desc = "Extract variable" },
      { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end,  mode = { "n", "v" }, desc = "Inline variable" },
    },
    opts = {},
  },

  -- Autopairs
  {
    "echasnovski/mini.pairs",
    event = "InsertEnter",
    config = true,
  },

  -- Surround (gs prefix)
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  -- Search and replace
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      { "<leader>sr", function() require("grug-far").open() end, desc = "Search and replace" },
    },
    config = true,
  },

  -- Jump navigation
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        char = { enabled = false }, -- don't hijack f/F/t/T
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,       desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- Inline markdown rendering (headings, code blocks, tables, lists)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    ft = { "markdown" },
    keys = {
      { "<leader>uM", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
    opts = {
      completions = { lsp = { enabled = true } },
      code = { width = "block", right_pad = 2 },
    },
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo comments" },
    },
  },

  -- Better buffer delete (preserves window layout)
  {
    "echasnovski/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end,  desc = "Delete buffer (force)" },
    },
  },

  -- Enhanced text objects (around/inside)
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = {},
  },

  -- Yank history ring
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      ring = { history_length = 100 },
    },
    keys = {
      { "y",     "<Plug>(YankyYank)",          mode = { "n", "x" },     desc = "Yank" },
      { "p",     "<Plug>(YankyPutAfter)",      mode = { "n", "x" },     desc = "Put after" },
      { "P",     "<Plug>(YankyPutBefore)",     mode = { "n", "x" },     desc = "Put before" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "Prev yank entry" },
      { "<C-n>", "<Plug>(YankyNextEntry)",     desc = "Next yank entry" },
    },
  },

  -- Documentation generator
  {
    "danymat/neogen",
    cmd = "Neogen",
    keys = {
      { "<leader>cn", function() require("neogen").generate() end, desc = "Generate annotation" },
    },
    opts = {
      snippet_engine = "nvim",
    },
  },

  -- Multi-cursor editing (VSCode-style match selection)
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
      { "<leader>mn", function() require("multicursor-nvim").matchAddCursor(1) end, mode = { "n", "x" }, desc = "Add cursor at next match" },
      { "<leader>mN", function() require("multicursor-nvim").matchAddCursor(-1) end, mode = { "n", "x" }, desc = "Add cursor at prev match" },
      { "<leader>ms", function() require("multicursor-nvim").matchSkipCursor(1) end, mode = { "n", "x" }, desc = "Skip match (next)" },
      { "<leader>mS", function() require("multicursor-nvim").matchSkipCursor(-1) end, mode = { "n", "x" }, desc = "Skip match (prev)" },
      { "<leader>ma", function() require("multicursor-nvim").matchAllAddCursors() end, mode = { "n", "x" }, desc = "Add cursor at all matches" },
      { "<leader>mx", function() require("multicursor-nvim").deleteCursor() end, mode = { "n", "x" }, desc = "Delete cursor under main" },
      { "<C-q>", function() require("multicursor-nvim").toggleCursor() end, mode = { "n", "x" }, desc = "Toggle cursor" },
    },
    config = function()
      require("multicursor-nvim").setup()
    end,
  },

  -- Jump between related files. Tuned for fl-gaf (PHP src/src2 + Angular webapp).
  --
  -- Test/source:
  --   src/<M>/Foo.php           ↔ test/unit/src/<M>/FooTest.php
  --                             ↔ test/functional/src/<M>/FooFunctionalTest.php
  --                             ↔ test/double/<M>/Foo.php (infra mocks — only src/Core/{Grpc,Rabbit})
  --   src2/<Type>/<M>/Foo.php   ↔ test/unit/src2/<Type>/<M>/FooTest.php (keeps type, majority)
  --                             ↔ test/unit/src2/<M>/FooTest.php (drops type — SwiftId, Verification/…)
  --                             ↔ test/functional/src2/<M>/FooFunctionalTest.php (majority)
  --                             ↔ test/functional/src2/<Type>/<M>/FooFunctionalTest.php (minority)
  --   consumers/Foo.php         ↔ test/functional/consumer/FooConsumerTest.php (rare)
  -- Cross-type (src2): Handler ↔ Service ↔ Controller ↔ Repository ↔ Command ↔ DTO
  --   e.g. src2/Handler/Ai/FooHandler.php ↔ src2/Service/Ai/FooService.php
  -- Interface: src2/<Type>/<M>/FooFooInterface.php ↔ src2/<Type>/<M>/FooFoo.php
  -- Angular: foo.component.ts ↔ .scss / .spec.ts / .module.ts / .types.ts /
  --                              .routes.ts / .resolver.ts / .helpers.ts /
  --                              -guard.service.ts / -route-matcher.ts / .animation.ts
  --          foo.service.ts   ↔ .spec.ts / .types.ts / .model.ts / .validators.ts /
  --                              .interface.ts / .config.ts / .helpers.ts / .effect.ts
  --          foo.directive.ts ↔ .directive.spec.ts   ; foo.pipe.ts ↔ .pipe.spec.ts
  --          foo.module.ts    ↔ foo-routing.module.ts / .routes.ts / .component.ts
  --          datastore hub: .backend.ts ↔ .backend-model.ts / .model.ts / .module.ts /
  --                         .reducer.ts / .seed.ts / .transformers.ts / .transformer.ts /
  --                         .types.ts (webapp @freelancer/datastore, @escrow/datastore)
  --          stories/<x>.story.ts → ../<folder>.component.ts / .directive.ts / .pipe.ts
  {
    "rgroli/other.nvim",
    main = "other-nvim", -- module is `other-nvim`, not `other` (lazy's default guess)
    cmd = { "Other", "OtherSplit", "OtherVSplit", "OtherClear" },
    -- `:Other` pops a picker listing every related file that actually exists
    -- (context labels shown alongside: service, handler, unit, functional, styles…).
    keys = {
      { "<leader>oo", "<cmd>Other<cr>",       desc = "Other: pick related file" },
      { "<leader>os", "<cmd>OtherSplit<cr>",  desc = "Other: pick (split)" },
      { "<leader>ov", "<cmd>OtherVSplit<cr>", desc = "Other: pick (vsplit)" },
    },
    opts = {
      rememberBuffers = false,
      showMissingFiles = false,
      style = {
        border = "rounded",
        minWidth = 30,
        width = 0.4,
        maxHeight = 0.3,
        seperator = "|",
        newFileIndicator = "(+)",
      },
      mappings = {
        -- ============================================================
        -- PHP legacy (src/)
        -- ============================================================
        {
          pattern = "/src/(.*)%.php$",
          target = {
            { target = "/test/unit/src/%1Test.php",                 context = "unit" },
            { target = "/test/functional/src/%1FunctionalTest.php", context = "functional" },
            { target = "/test/double/%1.php",                       context = "double" },
          },
        },
        { pattern = "/test/unit/src/(.*)Test%.php$",                  target = "/src/%1.php", context = "source" },
        { pattern = "/test/functional/src/(.*)FunctionalTest%.php$",  target = "/src/%1.php", context = "source" },
        -- Test doubles (infrastructure mocks for src/Core/{Grpc,Rabbit}).
        -- Exact path mirror of src/.
        { pattern = "/test/double/(.*)%.php$", target = "/src/%1.php", context = "source" },

        -- ============================================================
        -- RabbitMQ consumer scripts (consumers/)
        -- Consumer↔Handler naming is unreliable (only 3/222 match
        -- <name>ConsumerHandler.php), so no cross-type mapping. Only the
        -- rare functional test pair is modelled.
        --   consumers/PurgeActiveProjects.php ↔
        --     test/functional/consumer/PurgeActiveProjectsConsumerTest.php
        -- ============================================================
        {
          pattern = "/consumers/(.*)%.php$",
          target = { { target = "/test/functional/consumer/%1ConsumerTest.php", context = "functional" } },
        },
        { pattern = "/test/functional/consumer/(.*)ConsumerTest%.php$", target = "/consumers/%1.php", context = "source" },

        -- ============================================================
        -- PHP new (src2/) — per-type source → test
        -- ============================================================
        -- Each src2/<Type>/ pattern below offers both:
        --   test/unit/src2/<Type>/%1Test.php   — majority convention (keeps Type)
        --   test/unit/src2/%1Test.php          — drop-Type convention (SwiftId, Verification/…)
        {
          pattern = "/src2/Handler/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Handler/%1Test.php",                 context = "unit" },
            { target = "/test/unit/src2/%1Test.php",                         context = "unit-alt" },
            { target = "/test/functional/src2/%1FunctionalTest.php",         context = "functional" },
            { target = "/test/functional/src2/Handler/%1FunctionalTest.php", context = "functional-alt" },
          },
        },
        {
          pattern = "/src2/Service/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Service/%1Test.php",                 context = "unit" },
            { target = "/test/unit/src2/%1Test.php",                         context = "unit-alt" },
            { target = "/test/functional/src2/%1FunctionalTest.php",         context = "functional" },
            { target = "/test/functional/src2/Service/%1FunctionalTest.php", context = "functional-alt" },
          },
        },
        {
          pattern = "/src2/Controller/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Controller/%1Test.php",                 context = "unit" },
            { target = "/test/unit/src2/%1Test.php",                            context = "unit-alt" },
            { target = "/test/functional/src2/%1FunctionalTest.php",            context = "functional" },
            { target = "/test/functional/src2/Controller/%1FunctionalTest.php", context = "functional-alt" },
          },
        },
        {
          pattern = "/src2/Command/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Command/%1Test.php",                 context = "unit" },
            { target = "/test/unit/src2/%1Test.php",                         context = "unit-alt" },
            { target = "/test/functional/src2/%1FunctionalTest.php",         context = "functional" },
            { target = "/test/functional/src2/Command/%1FunctionalTest.php", context = "functional-alt" },
          },
        },
        {
          pattern = "/src2/Repository/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Repository/%1Test.php",                 context = "unit" },
            { target = "/test/unit/src2/%1Test.php",                            context = "unit-alt" },
            { target = "/test/functional/src2/%1FunctionalTest.php",            context = "functional" },
            { target = "/test/functional/src2/Repository/%1FunctionalTest.php", context = "functional-alt" },
          },
        },
        {
          pattern = "/src2/DTO/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/DTO/%1Test.php", context = "unit" },
            { target = "/test/unit/src2/%1Test.php",     context = "unit-alt" },
          },
        },
        {
          pattern = "/src2/Enum/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Enum/%1Test.php", context = "unit" },
            { target = "/test/unit/src2/%1Test.php",      context = "unit-alt" },
          },
        },
        {
          pattern = "/src2/Traits/(.*)%.php$",
          target = {
            { target = "/test/unit/src2/Traits/%1Test.php", context = "unit" },
            { target = "/test/unit/src2/%1Test.php",        context = "unit-alt" },
          },
        },

        -- src2 unit test → source. Most tests keep the Type segment (Handler/X/FooTest),
        -- so /src2/%1.php hits directly. For drop-Type tests (test/unit/src2/SwiftId/…,
        -- test/unit/src2/Verification/…), offer every Type candidate; non-existent ones
        -- are hidden by showMissingFiles=false.
        {
          pattern = "/test/unit/src2/(.*)Test%.php$",
          target = {
            { target = "/src2/%1.php",            context = "source" },
            { target = "/src2/Handler/%1.php",    context = "handler" },
            { target = "/src2/Service/%1.php",    context = "service" },
            { target = "/src2/Controller/%1.php", context = "controller" },
            { target = "/src2/Command/%1.php",    context = "command" },
            { target = "/src2/Repository/%1.php", context = "repository" },
            { target = "/src2/DTO/%1.php",        context = "dto" },
            { target = "/src2/Enum/%1.php",       context = "enum" },
            { target = "/src2/Traits/%1.php",     context = "traits" },
          },
        },
        -- src2 functional test → source: could live under any type dir; offer all candidates
        {
          pattern = "/test/functional/src2/(.*)FunctionalTest%.php$",
          target = {
            { target = "/src2/Handler/%1.php",    context = "handler" },
            { target = "/src2/Service/%1.php",    context = "service" },
            { target = "/src2/Controller/%1.php", context = "controller" },
            { target = "/src2/Command/%1.php",    context = "command" },
            { target = "/src2/Repository/%1.php", context = "repository" },
          },
        },

        -- ============================================================
        -- PHP src2 cross-type navigation (Handler ↔ Service ↔ … ↔ DTO)
        -- Base name is the file name minus its type suffix; module path carries over.
        -- Missing siblings are hidden by showMissingFiles=false.
        -- ============================================================
        {
          pattern = "/src2/Handler/(.*)Handler%.php$",
          target = {
            { target = "/src2/Service/%1Service.php",                  context = "service" },
            { target = "/src2/Controller/%1Controller.php",            context = "controller" },
            { target = "/src2/Repository/%1Repository.php",            context = "repository" },
            { target = "/src2/Command/%1Command.php",                  context = "command" },
            { target = "/src2/DTO/%1DTO.php",                          context = "dto" },
            { target = "/src2/Handler/%1HandlerInterface.php",         context = "interface" },
          },
        },
        {
          pattern = "/src2/Service/(.*)Service%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                  context = "handler" },
            { target = "/src2/Controller/%1Controller.php",            context = "controller" },
            { target = "/src2/Repository/%1Repository.php",            context = "repository" },
            { target = "/src2/Command/%1Command.php",                  context = "command" },
            { target = "/src2/DTO/%1DTO.php",                          context = "dto" },
            { target = "/src2/Service/%1ServiceInterface.php",         context = "interface" },
          },
        },
        {
          pattern = "/src2/Controller/(.*)Controller%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                  context = "handler" },
            { target = "/src2/Service/%1Service.php",                  context = "service" },
            { target = "/src2/Repository/%1Repository.php",            context = "repository" },
            { target = "/src2/DTO/%1DTO.php",                          context = "dto" },
            { target = "/src2/Controller/%1ControllerInterface.php",   context = "interface" },
          },
        },
        -- AjaxApi controllers: cross-type targets live under <Module>/ WITHOUT the
        -- AjaxApi/ segment (Handler/SwiftId/SwiftIdHandler.php, not Handler/AjaxApi/SwiftId/…).
        -- Aggregator controllers (e.g. BusinessBuilderController, which dispatches to
        -- many sub-handlers) won't find a 1:1 file — use LSP `gd` on the import.
        {
          pattern = "/src2/Controller/AjaxApi/(.*)Controller%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                            context = "handler" },
            { target = "/src2/Service/%1Service.php",                            context = "service" },
            { target = "/src2/Repository/%1Repository.php",                      context = "repository" },
            { target = "/src2/Command/%1Command.php",                            context = "command" },
            { target = "/src2/DTO/%1DTO.php",                                    context = "dto" },
            { target = "/test/functional/src2/%1ControllerFunctionalTest.php",   context = "functional" },
            { target = "/test/unit/src2/Controller/AjaxApi/%1ControllerTest.php", context = "unit" },
            { target = "/test/unit/src2/%1ControllerTest.php",                   context = "unit-alt" },
          },
        },
        {
          pattern = "/src2/Repository/(.*)Repository%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                  context = "handler" },
            { target = "/src2/Service/%1Service.php",                  context = "service" },
            { target = "/src2/Controller/%1Controller.php",            context = "controller" },
            { target = "/src2/DTO/%1DTO.php",                          context = "dto" },
            { target = "/src2/Repository/%1RepositoryInterface.php",   context = "interface" },
          },
        },
        {
          pattern = "/src2/Command/(.*)Command%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                  context = "handler" },
            { target = "/src2/Service/%1Service.php",                  context = "service" },
            { target = "/src2/Repository/%1Repository.php",            context = "repository" },
            { target = "/src2/DTO/%1DTO.php",                          context = "dto" },
          },
        },
        {
          pattern = "/src2/DTO/(.*)DTO%.php$",
          target = {
            { target = "/src2/Handler/%1Handler.php",                  context = "handler" },
            { target = "/src2/Service/%1Service.php",                  context = "service" },
            { target = "/src2/Controller/%1Controller.php",            context = "controller" },
            { target = "/src2/Repository/%1Repository.php",            context = "repository" },
            { target = "/src2/Command/%1Command.php",                  context = "command" },
          },
        },

        -- Interface ↔ implementation (same folder, strip "Interface" suffix)
        { pattern = "/src2/(.*)Interface%.php$", target = "/src2/%1.php", context = "impl" },
        { pattern = "/src/(.*)Interface%.php$",  target = "/src/%1.php",  context = "impl" },

        -- ============================================================
        -- Angular webapp (inline templates — no .component.html)
        -- Targets beyond the obvious are candidates — missing ones hidden by
        -- showMissingFiles=false. Each target's pattern below lists component.ts
        -- as a reverse target so navigation works both ways.
        -- ============================================================
        {
          pattern = "(.*)%.component%.ts$",
          target = {
            { target = "%1.component.scss",     context = "styles" },
            { target = "%1.component.spec.ts",  context = "test" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1-routing.module.ts",  context = "routing" },
            { target = "%1.routes.ts",          context = "routes" },
            { target = "%1.types.ts",           context = "types" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.helpers.ts",         context = "helpers" },
            { target = "%1.helper.ts",          context = "helper" },
            { target = "%1.resolver.ts",        context = "resolver" },
            { target = "%1.config.ts",          context = "config" },
            { target = "%1.interface.ts",       context = "interface" },
            { target = "%1.animation.ts",       context = "animation" },
            { target = "%1.validators.ts",      context = "validators" },
            { target = "%1.service.ts",         context = "service" },
            { target = "%1.guard.ts",           context = "guard" },
            { target = "%1-guard.service.ts",   context = "guard service" },
            { target = "%1-route-matcher.ts",   context = "route matcher" },
          },
        },
        {
          pattern = "(.*)%.component%.scss$",
          target = {
            { target = "%1.component.ts",      context = "component" },
            { target = "%1.component.spec.ts", context = "test" },
          },
        },
        {
          pattern = "(.*)%.component%.spec%.ts$",
          target = {
            { target = "%1.component.ts",   context = "component" },
            { target = "%1.component.scss", context = "styles" },
          },
        },

        {
          pattern = "(.*)%.service%.ts$",
          target = {
            { target = "%1.service.spec.ts", context = "test" },
            { target = "%1.types.ts",        context = "types" },
            { target = "%1.model.ts",        context = "model" },
            { target = "%1.validators.ts",   context = "validators" },
            { target = "%1.interface.ts",    context = "interface" },
            { target = "%1.config.ts",       context = "config" },
            { target = "%1.helpers.ts",      context = "helpers" },
            { target = "%1.helper.ts",       context = "helper" },
            { target = "%1.effect.ts",       context = "effect" },
            { target = "%1.module.ts",       context = "module" },
            { target = "%1.component.ts",    context = "component" },
          },
        },
        { pattern = "(.*)%.service%.spec%.ts$", target = "%1.service.ts", context = "source" },

        -- Directive / pipe hub files
        {
          pattern = "(.*)%.directive%.ts$",
          target = {
            { target = "%1.directive.spec.ts", context = "test" },
            { target = "%1.types.ts",          context = "types" },
            { target = "%1.animation.ts",      context = "animation" },
            { target = "%1.module.ts",         context = "module" },
          },
        },
        {
          pattern = "(.*)%.pipe%.ts$",
          target = {
            { target = "%1.pipe.spec.ts", context = "test" },
            { target = "%1.types.ts",     context = "types" },
            { target = "%1.module.ts",    context = "module" },
          },
        },

        -- Module ↔ routing module (feature-level routing pair) + siblings
        {
          pattern = "(.*)%-routing%.module%.ts$",
          target = {
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.component.ts",       context = "component" },
            { target = "%1.routes.ts",          context = "routes" },
            { target = "%1.resolver.ts",        context = "resolver" },
            { target = "%1-guard.service.ts",   context = "guard service" },
            { target = "%1-route-matcher.ts",   context = "route matcher" },
          },
        },
        {
          pattern = "(.*)%.module%.ts$",
          target = {
            { target = "%1-routing.module.ts",  context = "routing" },
            { target = "%1.component.ts",       context = "component" },
            { target = "%1.routes.ts",          context = "routes" },
            { target = "%1.service.ts",         context = "service" },
            { target = "%1.directive.ts",       context = "directive" },
            { target = "%1.pipe.ts",            context = "pipe" },
            { target = "%1.resolver.ts",        context = "resolver" },
            { target = "%1-guard.service.ts",   context = "guard service" },
            { target = "%1-route-matcher.ts",   context = "route matcher" },
            { target = "%1.effect.ts",          context = "effect" },
            -- datastore collection siblings
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
          },
        },

        -- Standalone routes / resolver / guard / route-matcher (page-level companions)
        {
          pattern = "(.*)%.routes%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.module.ts",    context = "module" },
          },
        },
        {
          pattern = "(.*)%.resolver%.ts$",
          target = {
            { target = "%1.component.ts",      context = "component" },
            { target = "%1.module.ts",         context = "module" },
            { target = "%1-routing.module.ts", context = "routing" },
            { target = "%1.service.ts",        context = "service" },
          },
        },
        {
          pattern = "(.*)%.guard%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.module.ts",    context = "module" },
            { target = "%1.service.ts",   context = "service" },
          },
        },
        {
          pattern = "(.*)%-guard%.service%.ts$",
          target = {
            { target = "%1-guard.service.spec.ts", context = "test" },
            { target = "%1.component.ts",          context = "component" },
            { target = "%1.module.ts",             context = "module" },
            { target = "%1-routing.module.ts",     context = "routing" },
          },
        },
        {
          pattern = "(.*)%-route%-matcher%.ts$",
          target = {
            { target = "%1-route-matcher.spec.ts", context = "test" },
            { target = "%1.component.ts",          context = "component" },
            { target = "%1.module.ts",             context = "module" },
            { target = "%1-routing.module.ts",     context = "routing" },
          },
        },

        -- Helpers / effect / interface / config / animation / validators (feature companions)
        {
          pattern = "(.*)%.helpers%.ts$",
          target = {
            { target = "%1.helpers.spec.ts", context = "test" },
            { target = "%1.component.ts",    context = "component" },
            { target = "%1.service.ts",      context = "service" },
            { target = "%1.module.ts",       context = "module" },
          },
        },
        {
          pattern = "(.*)%.helper%.ts$",
          target = {
            { target = "%1.helper.spec.ts", context = "test" },
            { target = "%1.component.ts",   context = "component" },
            { target = "%1.service.ts",     context = "service" },
          },
        },
        {
          pattern = "(.*)%.effect%.ts$",
          target = {
            { target = "%1.effect.spec.ts", context = "test" },
            { target = "%1.module.ts",      context = "module" },
            { target = "%1.config.ts",      context = "config" },
            { target = "%1.interface.ts",   context = "interface" },
            { target = "%1.service.ts",     context = "service" },
          },
        },
        {
          pattern = "(.*)%.interface%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.service.ts",   context = "service" },
            { target = "%1.module.ts",    context = "module" },
            { target = "%1.effect.ts",    context = "effect" },
          },
        },
        {
          pattern = "(.*)%.config%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.service.ts",   context = "service" },
            { target = "%1.module.ts",    context = "module" },
            { target = "%1.effect.ts",    context = "effect" },
          },
        },
        {
          pattern = "(.*)%.animation%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.directive.ts", context = "directive" },
          },
        },
        {
          pattern = "(.*)%.validators%.ts$",
          target = {
            { target = "%1.component.ts", context = "component" },
            { target = "%1.service.ts",   context = "service" },
            { target = "%1.module.ts",    context = "module" },
          },
        },
        {
          pattern = "(.*)%.validator%.ts$",
          target = {
            { target = "%1.validator.spec.ts", context = "test" },
            { target = "%1.component.ts",      context = "component" },
            { target = "%1.service.ts",        context = "service" },
          },
        },

        -- ============================================================
        -- Angular datastore collections (@freelancer/datastore, @escrow/datastore)
        -- Each collection folder: <name>/<name>.{backend,backend-model,model,module,
        --   reducer,seed,transformers,transformer,types}.ts
        -- Every collection file is a hub that jumps to its siblings.
        -- ============================================================
        {
          pattern = "(.*)%.backend%-model%.ts$",
          target = {
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
          },
        },
        {
          pattern = "(.*)%.backend%.ts$",
          target = {
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
          },
        },
        {
          pattern = "(.*)%.reducer%.ts$",
          target = {
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
          },
        },
        {
          pattern = "(.*)%.seed%.ts$",
          target = {
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
          },
        },
        {
          pattern = "(.*)%.transformers%.ts$",
          target = {
            { target = "%1.transformers.spec.ts", context = "test" },
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.types.ts",           context = "types" },
          },
        },
        {
          pattern = "(.*)%.transformer%.ts$",
          target = {
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.types.ts",           context = "types" },
          },
        },

        -- .model.ts and .types.ts are shared between datastore collections and
        -- feature folders; list both sibling groups, missing files are hidden.
        {
          pattern = "(.*)%.model%.ts$",
          target = {
            -- datastore siblings
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
            { target = "%1.types.ts",           context = "types" },
            -- feature-folder siblings
            { target = "%1.component.ts",       context = "component" },
            { target = "%1.service.ts",         context = "service" },
          },
        },
        {
          pattern = "(.*)%.types%.ts$",
          target = {
            -- feature-folder siblings
            { target = "%1.component.ts",       context = "component" },
            { target = "%1.service.ts",         context = "service" },
            { target = "%1.directive.ts",       context = "directive" },
            { target = "%1.pipe.ts",            context = "pipe" },
            -- datastore siblings
            { target = "%1.backend.ts",         context = "backend" },
            { target = "%1.backend-model.ts",   context = "backend-model" },
            { target = "%1.model.ts",           context = "model" },
            { target = "%1.module.ts",          context = "module" },
            { target = "%1.reducer.ts",         context = "reducer" },
            { target = "%1.seed.ts",            context = "seed" },
            { target = "%1.transformers.ts",    context = "transformers" },
            { target = "%1.transformer.ts",     context = "transformer" },
          },
        },

        -- ============================================================
        -- @freelancer/ui + components story files
        --   <folder>/stories/<x>.story.ts → ../<folder>.component.ts etc.
        -- Two captures: %1 = parent path, %2 = folder (== component base name).
        -- ============================================================
        {
          pattern = "(.*)/([^/]+)/stories/[^/]+%.story%.ts$",
          target = {
            { target = "%1/%2/%2.component.ts", context = "component" },
            { target = "%1/%2/%2.directive.ts", context = "directive" },
            { target = "%1/%2/%2.pipe.ts",      context = "pipe" },
            { target = "%1/%2/%2.service.ts",   context = "service" },
            { target = "%1/%2/%2.module.ts",    context = "module" },
            { target = "%1/%2/%2.types.ts",     context = "types" },
          },
        },

        -- Generic .spec.ts ↔ .ts fallback (covers lexical-ordering.spec.ts,
        -- *.helpers.spec.ts, *.effect.spec.ts, *.validator.spec.ts,
        -- *-guard.service.spec.ts, *-route-matcher.spec.ts, etc.)
        { pattern = "(.*)%.spec%.ts$", target = "%1.ts", context = "source" },
      },
    },
  },

  -- Subword motions (camelCase, snake_case aware)
  {
    "chrisgrieser/nvim-spider",
    event = "VeryLazy",
    config = function()
      local spider = require("spider")
      vim.keymap.set({ "n", "o", "x" }, "w", function() spider.motion("w") end, { desc = "Spider w" })
      vim.keymap.set({ "n", "o", "x" }, "e", function() spider.motion("e") end, { desc = "Spider e" })
      vim.keymap.set({ "n", "o", "x" }, "b", function() spider.motion("b") end, { desc = "Spider b" })
      vim.keymap.set({ "n", "o", "x" }, "ge", function() spider.motion("ge") end, { desc = "Spider ge" })
    end,
  },

  -- HTTP client (REST API testing)
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
    },
    ft = { "http", "rest" },
    opts = {
      global_keymaps = true,
      global_keymaps_prefix = "<leader>R",
      kulala_keymaps_prefix = "",
    },
  },

  -- Better quickfix window with preview + fzf filter
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      preview = { winblend = 0 },
    },
  },

  -- Search match count/index overlay
  {
    "kevinhwang91/nvim-hlslens",
    event = "VeryLazy",
    config = true,
  },

  -- Enhanced increment/decrement (booleans, dates, semver, etc.)
  {
    "monaqa/dial.nvim",
    keys = {
      { "<C-a>", function() require("dial.map").manipulate("increment", "normal") end, desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end, desc = "Decrement" },
      { "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, mode = "v",        desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, mode = "v",        desc = "Decrement" },
    },
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({
        default = {
          augend.integer.alias.decimal_int,
          augend.integer.alias.hex,
          augend.constant.alias.bool,
          augend.date.alias["%Y-%m-%d"],
          augend.date.alias["%Y/%m/%d"],
          augend.semver.alias.semver,
          augend.constant.new({ elements = { "true", "false" } }),
          augend.constant.new({ elements = { "True", "False" } }),
          augend.constant.new({ elements = { "yes", "no" } }),
          augend.constant.new({ elements = { "on", "off" } }),
          augend.constant.new({ elements = { "let", "const" } }),
          augend.constant.new({ elements = { "&&", "||" }, word = false }),
        },
      })
    end,
  },

  -- Better commentstring for embedded languages (JSX, Vue, etc.)
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Enhanced % matching for language constructs (if/else/end, etc.)
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  -- Create/edit snippets from Neovim
  {
    "chrisgrieser/nvim-scissors",
    dependencies = { "rafamadriz/friendly-snippets" },
    keys = {
      { "<leader>Se", function() require("scissors").editSnippet() end,   desc = "Edit snippet" },
      { "<leader>Sa", function() require("scissors").addNewSnippet() end, mode = { "n", "x" },  desc = "Add snippet" },
    },
    opts = {
      snippetDir = vim.fn.stdpath("data") .. "/lazy/friendly-snippets",
    },
  },

  -- Show marks in sign column
  {
    "chentoast/marks.nvim",
    event = "BufReadPost",
    opts = {
      default_mappings = true,
    },
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f",  group = "find" },
        { "<leader>s",  group = "search" },
        { "<leader>g",  group = "git" },
        { "<leader>gh", group = "hunks" },
        { "<leader>b",  group = "buffer" },
        { "<leader>q",  group = "quit/session" },
        { "<leader>t",  group = "todo" },
        { "<leader>u",  group = "ui" },
        { "<leader>x",  group = "diagnostics" },
        { "<leader>c",  group = "code" },
        { "<leader>cs", group = "swap" },
        { "<leader>d",  group = "debug" },
        { "<leader>T",  group = "test" },
        { "<leader>h",  group = "harpoon" },
        { "<leader>m",  group = "multicursor" },
        { "<leader>o",  group = "overseer" },
        { "<leader>r",  group = "refactor" },
        { "<leader>S",  group = "snippets" },
        { "<leader>l",  group = "laravel" },
        { "<leader>R",  group = "rest" },
        { "g",          group = "goto" },
        { "gs",         group = "surround" },
      },
    },
  },
  {
    "bngarren/checkmate.nvim",
    ft = "markdown", -- activates on markdown files matching `files` patterns below
    opts = {
      -- files = { "*.md" }, -- any .md file (instead of defaults)
      keys = {
        ["<leader>tt"] = { rhs = "<cmd>Checkmate toggle<CR>",          desc = "Toggle todo item",        modes = { "n", "v" } },
        ["<leader>tc"] = { rhs = "<cmd>Checkmate check<CR>",           desc = "Check todo item",         modes = { "n", "v" } },
        ["<leader>tu"] = { rhs = "<cmd>Checkmate uncheck<CR>",         desc = "Uncheck todo item",       modes = { "n", "v" } },
        ["<leader>t="] = { rhs = "<cmd>Checkmate cycle_next<CR>",      desc = "Cycle next state",        modes = { "n", "v" } },
        ["<leader>t-"] = { rhs = "<cmd>Checkmate cycle_previous<CR>",  desc = "Cycle previous state",    modes = { "n", "v" } },
        ["<leader>tn"] = { rhs = "<cmd>Checkmate create<CR>",          desc = "New todo item",           modes = { "n", "v" } },
        ["<leader>tx"] = { rhs = "<cmd>Checkmate remove<CR>",          desc = "Remove todo marker",      modes = { "n", "v" } },
        ["<leader>tR"] = { rhs = "<cmd>Checkmate metadata remove_all<CR>", desc = "Remove all metadata", modes = { "n", "v" } },
        ["<leader>ta"] = { rhs = "<cmd>Checkmate archive<CR>",         desc = "Archive completed",       modes = { "n" } },
        ["<leader>tf"] = { rhs = "<cmd>Checkmate select_todo<CR>",     desc = "Find todo (picker)",      modes = { "n" } },
        ["<leader>tv"] = { rhs = "<cmd>Checkmate metadata select_value<CR>", desc = "Set metadata value", modes = { "n" } },
        ["<leader>t]"] = { rhs = "<cmd>Checkmate metadata jump_next<CR>",     desc = "Next metadata tag",  modes = { "n" } },
        ["<leader>t["] = { rhs = "<cmd>Checkmate metadata jump_previous<CR>", desc = "Prev metadata tag",  modes = { "n" } },
      },
      -- Metadata `key` fields override the defaults' <leader>T* mappings onto <leader>t*.
      -- Providing an entry here fully replaces that metadata's default, so copy any fields you want to keep.
      metadata = {
        priority = {
          style = function(context)
            local value = context.value:lower()
            if value == "high" then
              return { fg = "#ff5555", bold = true }
            elseif value == "medium" then
              return { fg = "#ffb86c" }
            elseif value == "low" then
              return { fg = "#8be9fd" }
            else
              return { fg = "#8be9fd" }
            end
          end,
          get_value = function() return "medium" end,
          choices = function() return { "low", "medium", "high" } end,
          key = "<leader>tp",
          sort_order = 10,
          jump_to_on_insert = "value",
          select_on_insert = true,
        },
        started = {
          aliases = { "init" },
          style = { fg = "#9fd6d5" },
          get_value = function() return tostring(os.date("%m/%d/%y %H:%M")) end,
          key = "<leader>ts",
          sort_order = 20,
        },
        done = {
          aliases = { "completed", "finished" },
          style = { fg = "#96de7a" },
          get_value = function() return tostring(os.date("%m/%d/%y %H:%M")) end,
          key = "<leader>td",
          on_add = function(todo)
            require("checkmate").set_todo_state(todo, "checked")
          end,
          on_remove = function(todo)
            require("checkmate").set_todo_state(todo, "unchecked")
          end,
          sort_order = 30,
        },
      },
    },
  },

  -- Makes `.` repeat plugin mappings (mini.surround, yanky, etc.)
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- Case-preserving :Subvert/:S and `crs`/`crc`/`crm`/`cru`/`cr-`/`cr.` case coercions
  { "tpope/vim-abolish", event = "VeryLazy" },

  -- Structural (Treesitter) search & replace
  {
    "cshuaimin/ssr.nvim",
    keys = {
      { "<leader>sS", function() require("ssr").open() end, mode = { "n", "x" }, desc = "Structural replace (SSR)" },
    },
    opts = {
      border = "rounded",
      min_width = 50,
      min_height = 5,
      keymaps = {
        close = "q",
        next_match = "n",
        prev_match = "N",
        replace_confirm = "<cr>",
        replace_all = "<leader><cr>",
      },
    },
    config = function(_, opts)
      require("ssr").setup(opts)
    end,
  },

  -- Highlight other uses of the symbol under cursor (LSP/Treesitter/regex)
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 120,
        filetypes_denylist = { "oil", "trouble", "lazy", "mason", "help", "noice", "checkhealth", "snacks_picker_list" },
        min_count_to_highlight = 2,
      })
      vim.keymap.set("n", "]]", function() require("illuminate").goto_next_reference(false) end, { desc = "Next reference" })
      vim.keymap.set("n", "[[", function() require("illuminate").goto_prev_reference(false) end, { desc = "Prev reference" })
    end,
  },

  -- Better macro UX (edit, yank, named slots, status)
  {
    "chrisgrieser/nvim-recorder",
    event = "VeryLazy",
    opts = {
      slots = { "a", "b" },
      mapping = {
        startStopRecording = "q",
        playMacro = "Q",
        switchSlot = "<leader>qs",
        editMacro = "<leader>qe",
        yankMacro = "<leader>qy",
        addBreakPoint = "##",
      },
      clear = false,
      logLevel = vim.log.levels.INFO,
    },
  },
}
