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

	-- {
	-- 	"utilyre/barbecue.nvim",
	-- 	opts = {
	-- 		attach_navic = false,
	-- 		show_dirname = false,
	-- 		show_basename = false,
	-- 		show_modified = true,
	-- 		modifiers = {
	-- 			basename = "",
	-- 		},
	-- 		theme = "catppuccin",
	-- 	},
	-- 	event = { "BufReadPre", "BufNewFile" },
	-- },

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
	{
		"codethread/qmk.nvim",
		cmd = "QMKFormat",
		opts = {
			name = "LAYOUT_5x7_sym",
			layout = {
				"x x x x x x x _ x x x x x x x",
				"x x x x x x x _ x x x x x x x",
				"x x x x x x x _ x x x x x x x",
				"x x x x x x x _ x x x x x x x",
				"x x x x _ _ _ _ _ _ _ x x x x",
				"_ _ _ _ x x _ _ _ x x _ _ _ _",
				"_ _ _ _ _ x x _ x x _ _ _ _ _",
				"_ _ _ _ _ x x _ x x _ _ _ _ _",
			},
			comment_preview = {
				position = "inside",
				keymap_overrides = {
					LT_TAB_SYMBOLS = "  ",
					LT_BSPC_MOUSE = "  ",
					LT_QUOTE_MEDIA = "'  ",
					LT_ENTER_NUMBERS = "⏎  ",
					KC_LEFT = "←",
					KC_DOWN = "↓",
					KC_UP = "↑",
					KC_RIGHT = "→",
					_LAYER_BASE = "󰄮",
					_LAYER_MOUSE = "",
					_LAYER_MEDIA = "",
					_LAYER_SYM = "",
					_LAYER_NUMBERS = "",
					BASE = "󰄮",
					MOUSE = "",
					MEDIA = "",
					SYM = "",
					NUMBERS = "",
					LGUI_T = "Gui_T",
					RGUI_T = "Gui_T",
					LALT_T = "Alt_T",
					RALT_T = "AltGr_T",
					KC_LCTL = "LCTL",
					KC_RCTL = "RCTL",
					LCTL_T = "Ctrl_T",
					RCTL_T = "Ctrl_T",
					LSFT_T = "Shift_T",
					RSFT_T = "Shift_T",
					KC_LGUI = "LGUI",
					KC_RGUI = "RGUI",
					KC_LALT = "LALT",
					KC_RALT = "AltrGr",
					KC_LSFT = "LSFT",
					KC_RSFT = "RSFT",
					KC_MEDIA_DOWN = "ﱜ / ",
					KC_MEDIA_UP = "ﱛ / ",
					KC_BRID = "",
					KC_BRIU = "",
					KC_VOLD = "ﱜ",
					KC_VOLU = "ﱛ",
					SC_LSPO = "( ↑",
					SC_RSPC = ") ↑",
					KC_BSLS = "\\ |",
					KC_BACKSLASH = "\\ |",
					KC_GRAVE = "` ~",
					KC_BACKSPACE = "",
					KC_BSPC = "",
					KC_QUOTE = "' \"",
					KC_ARROW = "->",
					KC_EQUAL = "= +",
					KC_C_0 = "0 F10",
					KC_C_1 = "1 F1",
					KC_C_2 = "2 F2",
					KC_C_3 = "3 F3",
					KC_C_4 = "4 F4",
					KC_C_5 = "5 F5",
					KC_C_6 = "6 F6",
					KC_C_7 = "7 F7",
					KC_C_8 = "8 F8",
					KC_C_9 = "9 F9",
					KC_SLASH = "/ ?",
					KC_DOT = ". >",
					KC_PGUP = "Page ",
					KC_PGDN = "Page ",
					KC_MINUS = "- _",
					KC_COMMA = ", <",
					KC_TAB = "",
					KC_ENTER = "⏎",
					KC_SPACE = "␣",
					KC_SCLN = "; :",
					KC_MS_UP = " ↑",
					KC_MS_DOWN = " ↓",
					KC_MS_LEFT = " ←",
					KC_MS_RIGHT = " →",
					KC_WH_U = " WHEEL↑",
					KC_WH_D = " WHEEL↓",
					KC_WH_L = " WHEEL←",
					KC_WH_R = " WHEEL→",
					KC_MS_BTN1 = " BTN1",
					KC_MS_BTN2 = " BTN2",
					KC_MS_BTN3 = " BTN3",
					KC_ORIGIN = "󰭃",
					RGB_MOD = " ",
					RGB_HUD = " ←/→",
					RGB_VAD = " /",
					RGB_TOG = " ",
					AU_TOGG = "󰕿 ",
					AU_OFF = "󰖁",
					AU_ON = "",
					QK_BOOT = "",
					TD_BOOT = "󰍛",
					TD_EE_CLR = "󰘚",
					TD_SQBRKTL = "TD_[",
					TD_SQBRKTR = "TD_]",
					TD_REBOOT = "",
					TD_DEF_L_ = "def_",
					EEP_RST = "",
					QK_CLEAR_EEPROM = "EE_CLR",
					KC_Q = "Q",
					KC_W = "W",
					KC_E = "E",
					KC_R = "R",
					KC_T = "T",
					KC_Y = "Y",
					KC_U = "U",
					KC_I = "I",
					KC_O = "O",
					KC_P = "P",
					KC_A = "A",
					KC_S = "S",
					KC_D = "D",
					KC_F = "F",
					KC_G = "G",
					KC_H = "H",
					KC_J = "J",
					KC_K = "K",
					KC_L = "L",
					KC_Z = "Z",
					KC_X = "X",
					KC_C = "C",
					KC_V = "V",
					KC_B = "B",
					KC_N = "N",
					KC_M = "M",
					KC_F1 = "F1",
					KC_F2 = "F2",
					KC_F3 = "F3",
					KC_F4 = "F4",
					KC_F5 = "F5",
					KC_F6 = "F6",
					KC_F7 = "F7",
					KC_F8 = "F8",
					KC_F9 = "F9",
					KC_F10 = "F10",
					KC_F11 = "F11",
					KC_F12 = "F12",
					KC_DELETE = "DEL",
					KC_HOME = "HOME",
					KC_END = "END",
					KC_ESC = "ESC",
					KC_PRNT_HPT = "󰚱 ",
					HF_DWLD = "󰚱 ↓",
					HF_DWLU = "󰚱 ↑",
					HF_TOGG = "󰚱 ",
					KC_NO = "",
					_______ = "",
				},
			},
		},
	},
}
