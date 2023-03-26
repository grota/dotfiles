return {
	{
		"echasnovski/mini.bracketed",
		opts = {
			conflict = { suffix = "x", options = {} },
			diagnostic = { suffix = "d", options = {} },
			jump = { suffix = "j", options = {} },
			location = { suffix = "l", options = {} },
			quickfix = { suffix = "q", options = {} },
			treesitter = { suffix = "r", options = {} },
			yank = { suffix = "y", options = {} },
			oldfile = { suffix = "", options = {} },
			buffer = { suffix = "", options = {} },
			comment = { suffix = "", options = {} },
			undo = { suffix = "", options = {} },
			window = { suffix = "", options = {} },
			file = { suffix = "", options = {} },
			indent = { suffix = "", options = {} },
		},
		config = function(_, opts)
			require("mini.bracketed").setup(opts)
		end,
		event = { "BufReadPre", "BufNewFile" },
	},

	{
		"phpactor/phpactor",
		dir = "~/.local/share/nvim/mason/packages/phpactor/",
		ft = "php",
	},

	{
		"shumphrey/fugitive-gitlab.vim",
		init = function()
			vim.g.fugitive_gitlab_domains = { "https://gitlab.sparkfabrik.com" }
		end,
		cmd = "GBrowse",
		dependencies = {
			"tpope/vim-fugitive",
		},
	},

	{
		"rhysd/git-messenger.vim",
		init = function()
			vim.g.git_messenger_always_into_popup = true
		end,
		keys = {
			{ "<leader>gm", desc = "GitMessenger" },
		},
		cmd = "GitMessenger",
	},

	-- {
	-- 	"liuchengxu/vista.vim",
	-- 	init = function()
	-- 		vim.g.vista_default_executive = "nvim_lsp"
	-- 		vim.g.vista_echo_cursor = 0
	-- 	end,
	-- 	keys = {
	-- 		{ "<leader>uv", "<cmd>Vista!!<cr>", desc = "Open vista." },
	-- 	},
	-- },

	{
		"utilyre/barbecue.nvim",
		opts = {
			attach_navic = false,
			show_dirname = false,
			show_basename = false,
			show_modified = true,
			modifiers = {
				basename = "",
			},
			theme = "catppuccin",
		},
		event = { "BufReadPre", "BufNewFile" },
	},

	{
		"ckolkey/ts-node-action",
		dependencies = {
			"nvim-treesitter",
			"tpope/vim-repeat",
		},
		init = function()
			local nls = require("null-ls")
			nls.register({
				name = "more_actions",
				method = { nls.methods.CODE_ACTION },
				filetypes = { "_all" },
				generator = {
					fn = require("ts-node-action").available_actions,
				},
			})
		end,
	},

	{
		"tpope/vim-fugitive",
		event = { "BufReadPre", "BufNewFile" },
		keys = {
			{ "<leader>gs", "<cmd>Git<cr>", desc = "Fug. status" },
			{ "<leader>gd", "<cmd>Gdiffsplit<cr>", desc = "Fug. diff" },
			{ "<leader>gw", "<cmd>Gwrite<cr>", desc = "Fug. write" },
			{ "<leader>gb", "<cmd>Git blame<cr>", desc = "Fug. blame" },
			{ "<leader>gtec", "<cmd>Gtabedit @<cr>", desc = "Gtabedit @" },
			{ "<leader>gtel", ":Gtabedit <C-r>+<cr>", desc = "Gtabedit clipboard sha" },
		},
		init = function()
			local wk = require("which-key")
			wk.register({
				["<leader>gt"] = { name = "Git tab" },
				["<leader>gte"] = { name = "Git tab edit" },
			})
		end,
	},

	{
		"lfv89/vim-interestingwords",
		init = function()
			vim.g.interestingWordsDefaultMappings = 0
		end,
		keys = {
			{ "<leader>k", '<cmd>call InterestingWords("n")<cr>', mode = "n", desc = "Highlight word" },
			{ "<leader>k", '<cmd>call InterestingWords("v")<cr>', mode = "x", desc = "Highlight word" },
			{ "<leader>K", "<cmd>call UncolorAllWords()<cr>", mode = "n", desc = "Highlight uncolor" },
			{ "<leader>n", "<cmd>call WordNavigation(1)<cr>", mode = "n", desc = "Highlight next" },
			{ "<leader>N", "<cmd>call WordNavigation(0)<cr>", mode = "n", desc = "Highlight prev" },
		},
	},

	{
		"christoomey/vim-tmux-navigator",
		init = function()
			vim.g.tmux_navigator_no_mappings = 1
		end,
		keys = {
			{ "<M-S-Left>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go Left pane" },
			{ "<M-S-Right>", "<cmd>TmuxNavigateRight<cr>", desc = "Go Right pane" },
			{ "<M-S-Up>", "<cmd>TmuxNavigateUp<cr>", desc = "Go Up pane" },
			{ "<M-S-Down>", "<cmd>TmuxNavigateDown<cr>", desc = "Go Down pane" },
		},
	},

	{
		"nanozuki/tabby.nvim",
		config = function()
			require("tabby").setup()
		end,
		init = function()
			local presets = require("tabby.presets")
			local api = require("tabby.module.api")
			local tab_name = require("tabby.feature.tab_name")
			local hl_tabline_sel = "TabLineSel"
			local hl_tabline = "TabLine"
			local function tab_label(tabid, active)
				local icon = active and "" or ""
				-- local number = api.get_tab_number(tabid)
				local buf_name = require("tabby.feature.buf_name")
				local opts = {
					name_fallback = function(tabid2)
						local wins = api.get_tab_wins(tabid2)
						local cur_win = api.get_tab_current_win(tabid2)
						local name = ""
						if api.is_float_win(cur_win) then
							name = "[Floating]"
						else
							name = buf_name.get(cur_win)
						end
						if active and vim.bo[0].modified then
							name = name .. "+"
						end
						if #wins > 1 and not active then
							name = string.format("%s[%d]", name, #wins)
						end
						return name
					end,
				}
				local name = tab_name.get(tabid, opts)
				return string.format(" %s %s ", icon, name)
				-- return string.format(' %s %d: %s ', icon, number, name)
			end
			presets.active_wins_at_tail.head = nil
			presets.active_wins_at_tail.tail = nil
			presets.active_wins_at_tail.active_tab.label = function(tabid)
				return {
					tab_label(tabid, true),
					hl = hl_tabline_sel,
				}
			end
			presets.active_wins_at_tail.inactive_tab.label = function(tabid)
				return {
					tab_label(tabid),
					hl = hl_tabline,
				}
			end
		end,
	},

	{
		"mbbill/undotree",
		keys = {
			{ "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "UndoTree open." },
		},
	},

	{
		"AndrewRadev/linediff.vim",
		cmd = "Linediff",
	},
}
