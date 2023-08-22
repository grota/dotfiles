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
				lsp_references = {
					show_line = false,
				},
        lsp_implementations = {
					show_line = false,
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
			local vimgrep_hidden_no_dot_git = vim.deepcopy(telescope_default_vimgrep_arguments)
			vim.list_extend(vimgrep_hidden_no_dot_git, opts_hidden_no_dot_git)
			local vimgrep_arguments_for_all = vim.deepcopy(vimgrep_hidden_no_dot_git)
			vim.list_extend(vimgrep_arguments_for_all, opts_no_ignore)
			local find_all_files_cmd = {
				"rg",
				"--files",
				"--color",
				"never",
			}
			vim.list_extend(find_all_files_cmd, opts_hidden_no_dot_git)
			vim.list_extend(find_all_files_cmd, opts_no_ignore)
			local git_grep_vimgrep_args = {
				"git",
				"--no-pager",
				"grep",
				"--no-color",
				"--line-number",
				"--column",
				"-I", -- no binary files
			}
			local git_grep_ignore_case_vimgrep_args = vim.deepcopy(git_grep_vimgrep_args)
			vim.list_extend(git_grep_ignore_case_vimgrep_args, { "--ignore-case" })
			-- <leader>st is used by folke/todo-comments.nvim
			-- <leader>sn is used by folke/noice.nvim
			return {
				-- START Grepping section. ggs,ggi,gG
				{
					"<leader>ggs",
					function()
						require("telescope.builtin").live_grep({
							prompt_title = "Git Grep sensitive",
							vimgrep_arguments = git_grep_vimgrep_args,
							default_text = get_current_word_or_visual_selection(),
						})
					end,
					desc = "Telescope git grep case sensitive",
				},
				{
					"<leader>ggi",
					function()
						require("telescope.builtin").live_grep({
							prompt_title = "Git Grep in-sensitive",
							vimgrep_arguments = git_grep_ignore_case_vimgrep_args,
							default_text = get_current_word_or_visual_selection(),
						})
					end,
					desc = "Telescope git grep case insensitive",
				},
				{
					"<leader>gG",
					function()
						require("telescope.builtin").live_grep({
							prompt_title = "RipGrep all",
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
							prompt_title = "Search All files",
							find_command = find_all_files_cmd,
						})
					end,
					desc = "Telescope All Files",
				},
				-- START oldfiles section so,sO
				{
					"<leader>so",
					function()
						require("telescope.builtin")["oldfiles"]({
							prompt_title = "Oldfiles local",
							cwd_only = true,
						})
					end,
					desc = "Telescope Recent local",
				},
				{
					"<leader>sO",
					function()
						require("telescope.builtin")["oldfiles"]({
							prompt_title = "Oldfiles global",
						})
					end,
					desc = "Telescope Recent global",
				},
				-- START lsp symbols ss,sS
				{
					"<leader>ss",
          Util.telescope("lsp_document_symbols", {
            symbols = lsp_symbol_types,
            symbol_width = 60,
          }),
					desc = "Telescope Search Symbol (Document)",
				},
				{
					"<leader>sS",
          Util.telescope("lsp_workspace_symbols", {
            symbols = lsp_symbol_types,
            symbol_width = 60,
          }),
					desc = "Telescope Search Symbol (Workspace)",
				},
				-- START telescope prefixed.
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
				-- START various section.
				{
					"<leader>th",
					function()
						require("telescope.builtin")["keymaps"]({
							default_text = "'Telescope !'TelescopeFuzzyCommandSearch ",
						})
					end,
					desc = "Telescope help",
				},
				{ "<leader>,", "<cmd>Telescope buffers show_all_buffers=true<cr>", desc = "Telescope Switch Buffer" },
				{ "<leader>gS", "<cmd>Telescope git_status<CR>", desc = "Telescope git status" },
				{ "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Telescope search buffer" },
				{ "<leader>sC", "<cmd>Telescope command_history<cr>", desc = "Telescope Command History" },
				{ "<leader>sdb", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Telescope Diagnostics buffer" },
				{ "<leader>sda", "<cmd>Telescope diagnostics<cr>", desc = "Telescope Diagnostics all" },
				{ "<leader>sK", "<cmd>Telescope keymaps<cr>", desc = "Telescope Key Maps" },
				{ "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Telescope Man Pages" },
				{ "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Telescope Search Marks" },
				{ "<leader>wl", "<cmd>Telescope windows<cr>", desc = "Telescope window list" },
			}
		end,
		dependencies = {
			-- "tsakirist/telescope-lazy.nvim",
			"kyoh86/telescope-windows.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
			},
		},
		config = function(_, opts)
			local t = require("telescope")
			t.setup(opts)
			-- t.load_extension("lazy")
			t.load_extension("fzf")
			t.load_extension("windows")
		end,
		init = function()
			local wk = require("which-key")
			wk.register({
				["<leader>sd"] = { name = "Diagnostics" },
				["<leader>t"] = { name = "Telescope" },
				["<leader>gg"] = { name = "Git grep" },
			})
		end,
	},
}
