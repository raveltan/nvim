return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "igorlfs/nvim-dap-view",
        opts = {
          winbar = {
            sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "console" },
            default_section = "scopes",
          },
          windows = {
            size = 12,
          },
        },
        config = function(_, opts)
          local dap, dv = require("dap"), require("dap-view")
          dv.setup(opts)

          dap.listeners.before.attach["dap-view-config"] = function() dv.open() end
          dap.listeners.before.launch["dap-view-config"] = function() dv.open() end
          dap.listeners.before.event_terminated["dap-view-config"] = function() dv.close() end
          dap.listeners.before.event_exited["dap-view-config"] = function() dv.close() end
        end,
      },

      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },

      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
          ensure_installed = { "python", "php" },
          automatic_installation = true,
          handlers = {
            function(config)
              require("mason-nvim-dap").default_setup(config)
            end,
          },
        },
      },
    },
    keys = function()
      local keys = {
        { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
        { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
        { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
        { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
        { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
        { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
        { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
        { "<leader>du", function() require("dap-view").toggle() end, desc = "Toggle DAP UI" },
        { "<leader>de", "<cmd>DapViewWatch<cr>", desc = "Watch expression", mode = { "n", "v" } },
        { "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
      }
      if vim.g.gaf then
        vim.list_extend(keys, require("gaf.dap").keys())
      end
      return keys
    end,
    config = function()
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2e4030" })
      vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapBreakpointRejected",  { text = "", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapLogPoint",            { text = "◆", texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine" })

      if vim.g.gaf then require("gaf.dap").setup_php_configuration() end
    end,
  },
}
