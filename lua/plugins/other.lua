return {
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
        -- Ruby on Rails — comprehensive symmetrical navigation
        --
        -- Plural/singular bridge: Rails uses plural controller/view folder
        -- names (users_controller, views/users/) but singular model names
        -- (user.rb). Two pattern families handle both directions:
        --   • "(.+)s_controller" strips the trailing s → reaches the model
        --   • model targets append s → reach the controller
        -- showMissingFiles=false hides any path that doesn't exist, so
        -- offering both forms costs nothing.
        -- ============================================================

        -- Model → spec · controller (plural) · policy · serializer · decorator · form
        { pattern = "/app/models/(.+)%.rb$",
          target = {
            { target = "/spec/models/%1_spec.rb",              context = "spec" },
            { target = "/test/models/%1_test.rb",              context = "test" },
            { target = "/app/controllers/%1s_controller.rb",   context = "controller" },
            { target = "/app/controllers/%1_controller.rb",    context = "controller" },
            { target = "/app/policies/%1_policy.rb",           context = "policy" },
            { target = "/app/serializers/%1_serializer.rb",    context = "serializer" },
            { target = "/app/decorators/%1_decorator.rb",      context = "decorator" },
            { target = "/app/forms/%1_form.rb",                context = "form" },
          },
        },
        { pattern = "/spec/models/(.+)_spec%.rb$",
          target = {
            { target = "/app/models/%1.rb",                    context = "model" },
            { target = "/app/controllers/%1s_controller.rb",   context = "controller" },
            { target = "/app/controllers/%1_controller.rb",    context = "controller" },
          },
        },
        { pattern = "/test/models/(.+)_test%.rb$",
          target = {
            { target = "/app/models/%1.rb",                    context = "model" },
            { target = "/app/controllers/%1s_controller.rb",   context = "controller" },
          },
        },

        -- Controller (regular plural: users_controller) → model · spec · views · helper
        -- Pattern captures base WITHOUT trailing s so %1 = "user"
        { pattern = "/app/controllers/(.+)s_controller%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/spec/models/%1_spec.rb",                  context = "model spec" },
            { target = "/spec/controllers/%1s_controller_spec.rb", context = "spec" },
            { target = "/spec/requests/%1s_spec.rb",               context = "request spec" },
            { target = "/test/controllers/%1s_controller_test.rb", context = "test" },
            { target = "/app/views/%1s/index.html.erb",            context = "view:index" },
            { target = "/app/views/%1s/show.html.erb",             context = "view:show" },
            { target = "/app/views/%1s/new.html.erb",              context = "view:new" },
            { target = "/app/views/%1s/edit.html.erb",             context = "view:edit" },
            { target = "/app/views/%1s/_form.html.erb",            context = "view:_form" },
            { target = "/app/helpers/%1s_helper.rb",               context = "helper" },
            { target = "/app/policies/%1_policy.rb",               context = "policy" },
            { target = "/app/serializers/%1_serializer.rb",        context = "serializer" },
          },
        },
        -- Controller (same-name / non-plural) → spec · views · helper
        -- Separate pattern so it doesn't double-match plural controllers above
        { pattern = "/app/controllers/([^s].+)_controller%.rb$",
          target = {
            { target = "/spec/controllers/%1_controller_spec.rb",  context = "spec" },
            { target = "/spec/requests/%1_spec.rb",                context = "request spec" },
            { target = "/test/controllers/%1_controller_test.rb",  context = "test" },
            { target = "/app/views/%1/index.html.erb",             context = "view:index" },
            { target = "/app/views/%1/show.html.erb",              context = "view:show" },
            { target = "/app/views/%1/new.html.erb",               context = "view:new" },
            { target = "/app/views/%1/edit.html.erb",              context = "view:edit" },
            { target = "/app/views/%1/_form.html.erb",             context = "view:_form" },
            { target = "/app/helpers/%1_helper.rb",                context = "helper" },
          },
        },
        -- Controller spec (plural) → model · controller · request spec · views
        { pattern = "/spec/controllers/(.+)s_controller_spec%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/spec/requests/%1s_spec.rb",               context = "request spec" },
            { target = "/app/views/%1s/index.html.erb",            context = "view:index" },
          },
        },
        { pattern = "/spec/controllers/(.+)_controller_spec%.rb$",
          target = {
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/requests/%1_spec.rb",                context = "request spec" },
            { target = "/app/views/%1/index.html.erb",             context = "view:index" },
          },
        },
        -- Request spec (plural) → model · controller · controller spec
        { pattern = "/spec/requests/(.+)s_spec%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/spec/controllers/%1s_controller_spec.rb", context = "controller spec" },
          },
        },
        { pattern = "/spec/requests/(.+)_spec%.rb$",
          target = {
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/controllers/%1_controller_spec.rb",  context = "controller spec" },
          },
        },
        { pattern = "/test/controllers/(.+)_controller_test%.rb$",
          target = {
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
          },
        },

        -- View (plural folder) → model · controller · specs
        -- Pattern strips trailing s from folder: views/users/ → user
        { pattern = "/app/views/(.+)s/[^/]+%.html%.erb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/spec/controllers/%1s_controller_spec.rb", context = "spec" },
            { target = "/spec/requests/%1s_spec.rb",               context = "request spec" },
          },
        },
        -- View (non-plural / namespaced fallback) → controller · specs
        { pattern = "/app/views/(.+)/[^/]+%.html%.erb$",
          target = {
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/controllers/%1_controller_spec.rb",  context = "spec" },
            { target = "/spec/requests/%1_spec.rb",                context = "request spec" },
          },
        },
        { pattern = "/spec/views/(.+)/[^/]+_spec%.rb$",
          target = {
            { target = "/app/views/%1/index.html.erb",             context = "view:index" },
            { target = "/app/views/%1/show.html.erb",              context = "view:show" },
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
          },
        },

        -- Helper (plural: users_helper) → model · controller · spec
        { pattern = "/app/helpers/(.+)s_helper%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/spec/helpers/%1s_helper_spec.rb",         context = "spec" },
          },
        },
        { pattern = "/app/helpers/(.+)_helper%.rb$",
          target = {
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/helpers/%1_helper_spec.rb",          context = "spec" },
          },
        },
        { pattern = "/spec/helpers/(.+)_helper_spec%.rb$",
          target = {
            { target = "/app/helpers/%1_helper.rb",                context = "helper" },
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
          },
        },

        -- Mailer ↔ spec
        { pattern = "/app/mailers/(.+)%.rb$",
          target = {
            { target = "/spec/mailers/%1_spec.rb",                 context = "spec" },
            { target = "/test/mailers/%1_test.rb",                 context = "test" },
          },
        },
        { pattern = "/spec/mailers/(.+)_spec%.rb$",
          target = { { target = "/app/mailers/%1.rb",              context = "mailer" } },
        },
        { pattern = "/test/mailers/(.+)_test%.rb$",
          target = { { target = "/app/mailers/%1.rb",              context = "mailer" } },
        },

        -- Job ↔ spec
        { pattern = "/app/jobs/(.+)%.rb$",
          target = {
            { target = "/spec/jobs/%1_spec.rb",                    context = "spec" },
            { target = "/test/jobs/%1_test.rb",                    context = "test" },
          },
        },
        { pattern = "/spec/jobs/(.+)_spec%.rb$",
          target = { { target = "/app/jobs/%1.rb",                 context = "job" } },
        },
        { pattern = "/test/jobs/(.+)_test%.rb$",
          target = { { target = "/app/jobs/%1.rb",                 context = "job" } },
        },

        -- Service ↔ spec
        { pattern = "/app/services/(.+)%.rb$",
          target = {
            { target = "/spec/services/%1_spec.rb",                context = "spec" },
          },
        },
        { pattern = "/spec/services/(.+)_spec%.rb$",
          target = { { target = "/app/services/%1.rb",             context = "service" } },
        },

        -- Policy ↔ model · controller · spec  (Pundit)
        { pattern = "/app/policies/(.+)_policy%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/policies/%1_policy_spec.rb",         context = "spec" },
          },
        },
        { pattern = "/spec/policies/(.+)_policy_spec%.rb$",
          target = {
            { target = "/app/policies/%1_policy.rb",               context = "policy" },
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
          },
        },

        -- Serializer ↔ model · controller · spec
        { pattern = "/app/serializers/(.+)_serializer%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
            { target = "/app/controllers/%1_controller.rb",        context = "controller" },
            { target = "/spec/serializers/%1_serializer_spec.rb",  context = "spec" },
          },
        },
        { pattern = "/spec/serializers/(.+)_serializer_spec%.rb$",
          target = {
            { target = "/app/serializers/%1_serializer.rb",        context = "serializer" },
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/app/controllers/%1s_controller.rb",       context = "controller" },
          },
        },

        -- Decorator ↔ model · spec  (Draper)
        { pattern = "/app/decorators/(.+)_decorator%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/spec/decorators/%1_decorator_spec.rb",    context = "spec" },
          },
        },
        { pattern = "/spec/decorators/(.+)_decorator_spec%.rb$",
          target = {
            { target = "/app/decorators/%1_decorator.rb",          context = "decorator" },
            { target = "/app/models/%1.rb",                        context = "model" },
          },
        },

        -- Form ↔ model · spec
        { pattern = "/app/forms/(.+)_form%.rb$",
          target = {
            { target = "/app/models/%1.rb",                        context = "model" },
            { target = "/spec/forms/%1_form_spec.rb",              context = "spec" },
          },
        },
        { pattern = "/spec/forms/(.+)_form_spec%.rb$",
          target = {
            { target = "/app/forms/%1_form.rb",                    context = "form" },
            { target = "/app/models/%1.rb",                        context = "model" },
          },
        },

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
}
