return {

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 2, {
        function ()
          local icon = require("lazyvim.config").icons.kinds.Copilot
          return icon .. vim.fn['codeium#GetStatusString']()
        end,
        cond = function ()
          return vim.fn['codeium#GetStatusString']() ~= ' ON'
        end
      })
    end,
  },

	{
		"shumphrey/fugitive-gitlab.vim",
		init = function()
			vim.g.fugitive_gitlab_domains = { "https://gitlab.sparkfabrik.com" }
		end,
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

	{
		"kevinhwang91/nvim-bqf",
		event = "VimEnter",
		dependencies = {
			"junegunn/fzf",
		},
	},

	{
		"nvim-treesitter/nvim-treesitter-context",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
	},

	{
		"ckolkey/ts-node-action",
		dependencies = {
			"nvim-treesitter",
			"tpope/vim-repeat",
		},
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
			{ "<leader>gef", "<cmd>Gedit<cr>", desc = "Gedit" },
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
			vim.g.tmux_navigator_preserve_zoom = 1
		end,
		keys = {
			{ "<C-h>", '<cmd>TmuxNavigateLeft("n")<cr>', mode = "n", desc = "TmuxNavigateLeft" },
			{ "<C-j>", "<cmd>TmuxNavigateDown<cr>", mode = "n", desc = "TmuxNavigateDown" },
			{ "<C-k>", "<cmd>TmuxNavigateUp<cr>", mode = "n", desc = "TmuxNavigateUp" },
			{ "<C-l>", "<cmd>TmuxNavigateRight<cr>", mode = "n", desc = "TmuxNavigateRight" },
			{ "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", mode = "n", desc = "TmuxNavigatePrevious" },
		},
	},

  {
    "ThePrimeagen/harpoon",
		event = { "BufReadPre", "BufNewFile" },
    opts = {
      menu = {
        width = vim.api.nvim_win_get_width(0) - 4,
      }
    },
    keys = {
      { "<leader>hh", function () require("harpoon.ui").toggle_quick_menu() end, desc = "Harpoon list" },
      { "<leader>ha", function () require("harpoon.mark").add_file() end, desc = "Harpoon add" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
		init = function()
			local wk = require("which-key")
			wk.register({
				["<leader>h"] = { name = "Harpoon" },
			})
		end,
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
				local icon = active and "" or "" -- "󰝤" or "" -- '' or ''
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
			presets.active_wins_at_tail.win.label = function()
				return ""
			end
			presets.active_wins_at_tail.top_win.label = function()
				return ""
			end
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

	{
		"phpactor/phpactor",
		dir = "~/.local/share/nvim/mason/packages/phpactor/",
		ft = "php",
    keys = {
      {"<leader>pnd", ":PhpactorClassExpand<cr>", desc = "Phpactor Class Expand" },
      {"<leader>pxt", ":PhpactorExtractExpression<cr>", desc = "Phpactor Extract Expression", mode = { "n", "x" } },
    },
		init = function()
			local wk = require("which-key")
			wk.register({
				["<leader>p"] = { name = "Phpactor" },
				["<leader>pn"] = { name = "Phpactor Class Expand (type d)" },
				["<leader>px"] = { name = "Phpactor Extract Expression (type t)" },
			})
		end,
	},

}
