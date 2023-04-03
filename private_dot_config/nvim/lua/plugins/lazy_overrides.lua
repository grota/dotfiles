local function get_current_word_or_visual_selection()
	local word
	local visual = vim.fn.mode() == "v"

	if visual == true then
		local saved_reg = vim.fn.getreg("v")
		vim.cmd([[noautocmd sil norm "vy]])
		local sele = vim.fn.getreg("v")
		vim.fn.setreg("v", saved_reg)
		word = sele
	else
		word = vim.fn.expand("<cword>")
	end
	return word
end
return {
	{
		"echasnovski/mini.ai",
		opts = function(_, opts)
			local ai = require("mini.ai")
			opts.custom_textobjects.S = ai.gen_spec.treesitter({
				a = { "@statement.outer", "@function.outer" },
				i = { "@statement.outer", "@function.inner" },
			}, {})
		end,
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
			-- I prefer https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#mapping-c-u-to-clear-prompt
			-- C-d wiped for symmetry.
			opts.defaults.mappings.i["<C-u>"] = false
			opts.defaults.mappings.i["<C-d>"] = false
			opts.defaults.wrap_results = true
			opts.defaults.layout_config = {
				horizontal = {
					width = 0.9,
					prompt_position = "top",
				},
			}
			local wipe_selected_buffers = function(prompt_bufnr)
				local action_state = require("telescope.actions.state")
				local actions = require("telescope.actions")
				local picker = action_state.get_current_picker(prompt_bufnr)
				for _, entry in ipairs(picker:get_multi_selection()) do
					vim.api.nvim_buf_delete(entry.bufnr, {})
				end
				actions.close(prompt_bufnr)
			end
			opts.pickers = {
				buffers = {
					mappings = {
						i = {
							["<C-d>"] = wipe_selected_buffers,
						},
					},
				},
			}
		end,
		keys = function()
			local Util = require("lazyvim.util")
			local lsp_symbol_types = {
				"Class",
				"Function",
				"Method",
				"Constructor",
				"Interface",
				"Module",
				"Struct",
				"Trait",
				"Field",
				"Property",
			}
			-- telescope_default_vimgrep_arguments = {
			--   "rg",
			--   "--color=never",
			--   "--no-heading",
			--   "--with-filename",
			--   "--line-number",
			--   "--column",
			--   "--smart-case"
			-- }
			local telescope_default_vimgrep_arguments = require("telescope.config").values.vimgrep_arguments
			local opts_hidden_no_dot_git = {
				"--hidden",
				"-g=!.git/**",
			}
			local opts_no_ignore = {
				"--no-ignore",
				"--no-ignore-parent",
			}
			local vimgrep_hidden_no_dot_git = telescope_default_vimgrep_arguments
			vim.list_extend(vimgrep_hidden_no_dot_git, opts_hidden_no_dot_git)
			local vimgrep_arguments_for_all = vimgrep_hidden_no_dot_git
			vim.list_extend(vimgrep_arguments_for_all, opts_no_ignore)
			local find_all_files_cmd = {
				"rg",
				"--files",
				"--color",
				"never",
			}
			vim.list_extend(find_all_files_cmd, opts_hidden_no_dot_git)
			vim.list_extend(find_all_files_cmd, opts_no_ignore)
			-- <leader>st is used by folke/todo-comments.nvim
			-- <leader>sn is used by folke/noice.nvim
			return {
				-- START Grepping section. gg,gG
				{
					"<leader>gg",
					function()
						require("telescope.builtin").live_grep({
							vimgrep_arguments = vimgrep_hidden_no_dot_git,
							default_text = get_current_word_or_visual_selection(),
						})
					end,
					desc = "Telescope Grep",
				},
				{
					"<leader>gG",
					function()
						require("telescope.builtin").live_grep({
							vimgrep_arguments = vimgrep_arguments_for_all,
							default_text = get_current_word_or_visual_selection(),
						})
					end,
					desc = "Telescope Grep all",
				},
				-- START files section sf,sF
				{ "<leader>sf", "<cmd>Telescope git_files<cr>", desc = "Telescope Git Files" },
				{
					"<leader>sF",
					function()
						require("telescope.builtin").find_files({
							find_command = find_all_files_cmd,
						})
					end,
					desc = "Telescope All Files",
				},
				-- START oldfiles section so,sO
				{
					"<leader>so",
					function()
						require("telescope.builtin")["oldfiles"]({ cwd_only = true })
					end,
					desc = "Telescope Recent local",
				},
				{ "<leader>sO", "<cmd>Telescope oldfiles<cr>", desc = "Telescope Recent global" },
				-- START lsp symbols ss,sS
				{
					"<leader>ss",
					Util.telescope("lsp_document_symbols", { symbols = lsp_symbol_types }),
					desc = "Telescope Search Symbol (Document)",
				},
				{
					"<leader>sS",
					Util.telescope("lsp_workspace_symbols", { symbols = lsp_symbol_types }),
					desc = "Telescope Search Symbol (Workspace)",
				},
				-- START telescope prefilled
				{
					"<leader>tpl",
					function()
						require("telescope.builtin")["builtin"]({ default_text = "lsp_" })
					end,
					desc = "Telescope lsp_*",
				},
				{
					"<leader>tpp",
					function()
						require("telescope.builtin")["commands"]({ default_text = "Phpactor" })
					end,
					mode = { "n", "x" },
					desc = "Telescope Phpactor*",
				},
				{ "<leader>tz", "<cmd>Telescope lazy<cr>", desc = "Telescope for lazy" },
				{
					"<leader>th",
					function()
						require("telescope.builtin")["keymaps"]({
							default_text = "'Telescope !'TelescopeFuzzyCommandSearch ",
						})
					end,
					desc = "Telescope help",
				},
				-- START various section.
				{ "<leader>,", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Telescope Switch Buffer" },
				{ "<leader>gS", "<cmd>Telescope git_status<CR>", desc = "Telescope git status" },
				{ "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Telescope search buffer" },
				{ "<leader>sC", "<cmd>Telescope command_history<cr>", desc = "Telescope Command History" },
				{ "<leader>sdb", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Telescope Diagnostics buffer" },
				{ "<leader>sda", "<cmd>Telescope diagnostics<cr>", desc = "Telescope Diagnostics all" },
				{ "<leader>sK", "<cmd>Telescope keymaps<cr>", desc = "Telescope Key Maps" },
				{ "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Telescope Man Pages" },
				{ "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Telescope Search Marks" },
			}
		end,
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
			wk.register({
				["<leader>sd"] = { name = "Diagnostics" },
				["<leader>t"] = { name = "Telescope" },
			})
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
				-- move = { enable = false },
				-- select = { enable = false },
				-- lsp_interop = { enable = false },
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
				"vimdoc",
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

	{
		-- this simply did not work out for me, I need a real tabline not a bufferline.
		"akinsho/bufferline.nvim",
		enabled = false,
	},

	{
		"windwp/nvim-spectre",
		enabled = false,
	},
}
