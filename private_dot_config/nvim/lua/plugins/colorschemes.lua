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
					}
				end,
				integrations = {
					-- This only changes the hl of the navic parts.
					navic = {
						enabled = true,
						custom_bg = "NONE",
					},
				},
			})
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
		--enabled = false,
	},
}
