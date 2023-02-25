return {
	{
		-- not that tokyonight is bad, I just want a warmer one and changing the
		-- colorscheme is an easy way to dip my toes in lua water.
		"folke/tokyonight.nvim",
		enabled = false,
	},
	{
		"catppuccin/nvim",
		lazy = false,
		priority = 1000,
		name = "catppuccin",
		config = function()
			require("catppuccin").setup({
				color_overrides = {
					mocha = {
						base = "#000000",
						mauve = "#FFB703",
						lavender = "#6C584C",
						peach = "#A2D2FF",
						text = "#F2F5E0",
					},
				},
				dim_inactive = {
					enabled = true,
					shade = "dark",
					percentage = 0.85,
				},
				custom_highlights = function(colors)
					return {
						Search = { bg = "#875f00", fg = "black" },
						CurSearch = { bg = "#dfaf00", fg = "black" },
						DiffChange = { bg = "#5f005f" },
						DiffText = { bg = "#005f00" },
						DiffAdd = { bg = "#005f00" },
						DiffDelete = { bg = "#5f0000" },
						diffAdded = { fg = "#00aa00" },
						diffRemoved = { fg = "#dd0022" },
					}
				end,
				integrations = {
					navic = {
						enabled = true,
						custom_bg = "NONE",
					},
					gitsigns = true,
					leap = true,
					markdown = true,
					telescope = true,
					mason = true,
					neotree = true,
					noice = true,
					cmp = true,
					lsp_trouble = true,
					illuminate = true,
					which_key = true,
					treesitter = true,
					indent_blankline = {
						enabled = true,
					},
					native_lsp = {
						enabled = true,
						virtual_text = {
							errors = { "italic" },
							hints = { "italic" },
							warnings = { "italic" },
							information = { "italic" },
						},
						underlines = {
							errors = { "underline" },
							hints = { "underline" },
							warnings = { "underline" },
							information = { "underline" },
						},
					},
				},
			})
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
		--enabled = false,
	},
}
