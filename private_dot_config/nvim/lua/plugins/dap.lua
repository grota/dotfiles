return {
  {
    "mfussenegger/nvim-dap",
    keys = function()
      return {
        -- edit = "e",
        -- expand = { "<CR>", "<2-LeftMouse>" },
        -- open = "o",
        -- remove = "d",
        -- repl = "r",
        -- toggle = "t"
        { "<leader>dC", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
        { "<leader>dt", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
        { "<leader>ds", function() require("dap").continue() end, desc = "Start/Continue" },
        { "<leader>dc", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
        { "<leader>dj", function() require("dap").down() end, desc = "Down" },
        { "<leader>dk", function() require("dap").up() end, desc = "Up" },
        { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
        { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
        { "<leader>du", function() require("dap").step_out() end, desc = "Step Out" },
        { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
        { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
        { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
        { "<leader>dS", function() require("dap").session() end, desc = "Session" },
        { "<leader>dx", function() require("dap").terminate() end, desc = "Terminate" },
        { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
        { "<leader>dd", function() require('dap').disconnect() end, desc = "Disconnect" }, -- same as terminate at least in php
        { "<leader>dq", "<cmd>lua require'dap'.close()<cr>", desc = "Quit" },
      }
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    keys = function()
      return {
			{
				"<leader>de",
        function() require("dapui").eval(vim.fn.input '[Expression] > ') end,
				desc = "Evaluate Input",
			},
      { "<leader>de", function() require('dapui').eval() end, mode = "x", desc = "Evaluate" },
			{ "<leader>dE", function() require('dapui').eval() end, desc = "Evaluate word" },
			{ "<leader>dU", function() require('dapui').toggle() end, desc = "Toggle UI" },
    }
    end
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      automatic_installation = true,
      ensure_installed = { "php" },
      handlers = {
        php = function(config)
          config.configurations[1].port = 9003
          config.configurations[1].pathMappings =
          { ["/var/www/html/"] = [[${workspaceFolder}/src/drupal]] }
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  }
}
