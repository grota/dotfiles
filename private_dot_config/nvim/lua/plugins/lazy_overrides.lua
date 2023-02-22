return {
	{
		-- this simply did not work out for me, I need a real tabline not a bufferline.
		"akinsho/bufferline.nvim",
		enabled = false,
	},

	{
		"neovim/nvim-lspconfig",
		init = function()
			local keys = require("lazyvim.plugins.lsp.keymaps").get()
			keys[#keys + 1] = { "<leader>cl", false }
			keys[#keys + 1] = { "<leader>cL", "<cmd>LspInfo<cr>", desc = "Lsp Info" }
		end,
	},

	{
		-- Remove the keys part, I only want to use <M-n> and <M-p>
		-- And I also don't want to lose the ]] and [[ mappings from core ft.
		"RRethy/vim-illuminate",
		keys = function(_, _)
			return {}
		end,
		opts = {
			filetype_overrides = {
				-- There seems to be a bug in one of the 2 lsp I use in supporting the next word (<M-n>)
				php = {
					providers = { "treesitter" },
				},
			},
		},
		config = function(_, opts)
			require("illuminate").configure(opts)
		end,
	},

	{
		"nvim-neo-tree/neo-tree.nvim",
		opts = {
			source_selector = {
				winbar = true,
			},
			window = {
				auto_expand_width = true,
				mappings = {
					["<cr>"] = function(state)
						local utils = require("neo-tree.utils")
						local node = state.tree:get_node()
						state.commands["open"](state)
						if utils.is_expandable(node) then
							vim.cmd.normal("j")
						end
					end,
				},
			},
			filesystem = {
				-- bind_to_cwd = true,
				commands = {
					go_up_in_tree = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" and node:is_expanded() then
							require("neo-tree.sources.filesystem").toggle_directory(state, node)
						end
						require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
					end,
					go_down_in_tree = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" then
							if not node:is_expanded() then
								require("neo-tree.sources.filesystem").toggle_directory(state, node)
								vim.cmd.normal("j")
							elseif node:has_children() then
								require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
							end
						else
							state.commands["open"](state)
						end
					end,
				},
				window = {
					mappings = {
						["/"] = "none",
						["f"] = "focus_preview",
						["h"] = "go_up_in_tree",
						["l"] = "go_down_in_tree",
					},
				},
				filtered_items = {
					hide_dotfiles = false,
					hide_gitignored = false,
					hide_hidden = false,
				},
			},
			buffers = {
				follow_current_file = true,
			},
		},
	},

	{
		"nvim-telescope/telescope.nvim",
		opts = function(_, opts)
			opts.defaults.mappings.i["<a-i>"] = false
			opts.defaults.mappings.i["<a-h>"] = false
			opts.defaults.mappings.i["<C-j>"] = "move_selection_next"
			opts.defaults.mappings.i["<C-k>"] = "move_selection_previous"
			opts.defaults.mappings.i["<c-t>"] = "select_tab" -- C needs to stay lowercase because it's like that in Lazyvim
			-- section only slightly modified to pass func directly to have telescope's which-key with something.
			opts.defaults.mappings.i["<C-S-t>"] = require("trouble.providers.telescope").open_with_trouble
			opts.defaults.mappings.i["<C-Down>"] = "cycle_history_next"
			opts.defaults.mappings.i["<C-Up>"] = "cycle_history_prev"
			opts.defaults.mappings.i["<C-f>"] = "preview_scrolling_down"
			opts.defaults.mappings.i["<C-b>"] = "preview_scrolling_up"
			opts.defaults.vimgrep_arguments = {
				"rg",
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--smart-case",
				"--hidden",
			}
		end,
		keys = {
			{ "<leader>gc", false },
			{ "<leader>gs", false },
			{ "<leader>uC", false },
			{ "<leader><space>", false }, -- using <leader>ff
			{ "<leader>fB", "<cmd>Telescope<cr>", desc = "Telescope builtin." },
			{ "<leader>fL", "<cmd>Telescope lazy<cr>", desc = "Telescope for lazy." },
			{ "<leader>fr", false },
			{ "<leader>frg", "<cmd>Telescope oldfiles<cr>", desc = "Recent global" },
			{
				"<leader>frl",
				function()
					require("telescope.builtin")["oldfiles"]({ cwd_only = true })
				end,
				desc = "Recent local",
			},
		},
		dependencies = {
			"tsakirist/telescope-lazy.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
			},
		},
		config = function(_, opts)
			local t = require("telescope")
			t.setup(opts)
			t.load_extension("lazy")
			t.load_extension("fzf")
		end,
		init = function()
			local wk = require("which-key")
			wk.register({ ["<leader>fr"] = { name = "Find Recent" } })
		end,
	},

	{
		"williamboman/mason.nvim",
		opts = function(_, o)
			o.ensure_installed = {
				"stylua",
				"shellcheck",
				"shfmt",
				"phpactor",
				"intelephense",
				"lua-language-server",
				"flake8",
			}
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			textobjects = {
				move = { enable = false },
				select = { enable = false },
				lsp_interop = { enable = false },
				swap = {
					enable = true,
					swap_next = {
						["<leader>c<Right>"] = "@parameter.inner",
					},
					swap_previous = {
						["<leader>c<Left>"] = "@parameter.inner",
					},
				},
			},
			ensure_installed = {
				"bash",
				"help",
				"html",
				"javascript",
				"json",
				"jsonc",
				"lua",
				"markdown",
				"markdown_inline",
				"query",
				"regex",
				"tsx",
				"typescript",
				"vim",
				"yaml",
				"php",
				"phpdoc",
				"dockerfile",
				"twig",
			},
		},
	},

	{
		"jose-elias-alvarez/null-ls.nvim",
		opts = function()
			local nls = require("null-ls")
			return {
				sources = {
					nls.builtins.code_actions.shellcheck,
					nls.builtins.formatting.stylua,
					nls.builtins.diagnostics.flake8,
				},
			}
		end,
	},
	{
		"folke/noice.nvim",
		keys = {
			{ "<leader>snd", "<cmd>NoiceDisable<cr>", desc = "Noice disable" },
		},
	},

	{
		"goolord/alpha-nvim",
		opts = function(_, opts)
			local logo = [[




███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ]]
			opts.section.header.val = vim.split(logo, "\n")
		end,
	},
}
