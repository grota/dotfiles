return {
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
		},
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
}
