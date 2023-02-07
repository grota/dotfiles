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
			})
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
		--enabled = false,
	},
}
