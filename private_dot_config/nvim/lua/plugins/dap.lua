return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			{
				"mfussenegger/nvim-dap",
				name = "dap",
				init = function()
					local dap_breakpoint = {
						error = {
							text = "",
							texthl = "LspDiagnosticsSignError",
							linehl = "",
							numhl = "",
						},
						rejected = {
							text = "",
							texthl = "LspDiagnosticsSignHint",
							linehl = "",
							numhl = "",
						},
						stopped = {
							text = "",
							texthl = "LspDiagnosticsSignInformation",
							linehl = "DiagnosticUnderlineInfo",
							numhl = "LspDiagnosticsSignInformation",
						},
					}

					vim.fn.sign_define("DapBreakpoint", dap_breakpoint.error)
					vim.fn.sign_define("DapStopped", dap_breakpoint.stopped)
					vim.fn.sign_define("DapBreakpointRejected", dap_breakpoint.rejected)
				end,
				dependencies = {
					{
						"jay-babu/mason-nvim-dap.nvim",
						opts = {
							ensure_installed = { "php" },
							automatic_setup = {
								configurations = function(default)
									default.php[1].port = 9003
									default.php[1].pathMappings =
										{ ["/var/www/html/"] = [[${workspaceFolder}/src/drupal]] }
									return default
								end,
							},
						},
						config = function(_, opts)
							local mnd = require("mason-nvim-dap")
							mnd.setup(opts)
							mnd.setup_handlers({})
						end,
						dependencies = {
							"mason.nvim",
							"dap",
						},
					},
				},
			},

			{
				"theHamsta/nvim-dap-virtual-text",
				opts = {
					commented = true, -- prefix virtual text with comment string
					only_first_definition = false, -- only show virtual text at first definition (if there are multiple)
					all_references = true, -- show virtual text on all references of the variable (not only definitions)
				},
				dependencies = {
					"dap",
					"nvim-treesitter/nvim-treesitter",
				},
				keys = {
					{ "<leader>dT", "<cmd>DapVirtualTextToggle<cr>", desc = "Toggle dap virtualtext" },
				},
			},

			{
				"nvim-telescope/telescope-dap.nvim",
				config = function(_, _)
					require("telescope").load_extension("dap")
				end,
				dependencies = {
					"nvim-telescope/telescope.nvim",
				},
				keys = {
					{ "<leader>dv", "<cmd>Telescope dap variables<cr>", desc = "Telescope dap vars" },
				},
			},
		},
		-- init = function()
		-- require("neodev").setup({
		-- 	library = { plugins = { "nvim-dap-ui" }, types = true },
		-- })
		-- end,
		config = function(_, _)
			local dap, dapui = require("dap"), require("dapui")
			dapui.setup({})
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
		keys = {
			{ "<leader>ds", "<cmd>lua require'dap'.continue()<cr>", desc = "Start/Continue" },
			{ "<leader>do", "<cmd>lua require'dap'.step_over()<cr>", desc = "Step Over" },
			{ "<leader>di", "<cmd>lua require'dap'.step_into()<cr>", desc = "Step Into" },
			{ "<leader>du", "<cmd>lua require'dap'.step_out()<cr>", desc = "Step Out" },
			{ "<leader>dR", "<cmd>lua require'dap'.run_to_cursor()<cr>", desc = "Run to Cursor" },
			{ "<leader>dt", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", desc = "Toggle Breakpoint" },
			{
				"<leader>dC",
				"<cmd>lua require'dap'.set_breakpoint(vim.fn.input '[Condition] > ')<cr>",
				desc = "Conditional Breakpoint",
			},
			-- edit = "e",
			-- expand = { "<CR>", "<2-LeftMouse>" },
			-- open = "o",
			-- remove = "d",
			-- repl = "r",
			-- toggle = "t"
			{
				"<leader>de",
				"<cmd>lua require'dapui'.eval(vim.fn.input '[Expression] > ')<cr>",
				desc = "Evaluate Input",
			},
			{ "<leader>dE", "<cmd>lua require'dapui'.eval()<cr>", desc = "Evaluate word" },
			{ "<leader>de", "<cmd>lua require'dapui'.eval()<cr>", mode = "x", desc = "Evaluate" },
			{ "<leader>dU", "<cmd>lua require'dapui'.toggle()<cr>", desc = "Toggle UI" },
			{ "<leader>db", "<cmd>lua require'dap'.step_back()<cr>", desc = "Step Back" },
			{ "<leader>dx", "<cmd>lua require'dap'.terminate()<cr>", desc = "Terminate" }, -- same as disconnect at least in php
			{ "<leader>dd", "<cmd>lua require'dap'.disconnect()<cr>", desc = "Disconnect" }, -- same as terminate at least in php
			{ "<leader>dq", "<cmd>lua require'dap'.close()<cr>", desc = "Quit" },
		},
	},
}
