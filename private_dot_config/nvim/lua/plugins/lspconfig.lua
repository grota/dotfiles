return {
	{
		"neovim/nvim-lspconfig",
		init = function()
			local keys = require("lazyvim.plugins.lsp.keymaps").get()
			keys[#keys + 1] = { "<leader>cl", false }
			keys[#keys + 1] = { "<leader>cL", "<cmd>LspInfo<cr>", desc = "Lsp Info" }
		end,
		opts = function(_, opts)
			-- return true if you don't want this server to be setup with lspconfig
			opts.setup.clangd = function(_, o)
				o.capabilities.offsetEncoding = { "utf-16" }
				return false
			end
			opts.setup.yamlls = function(_, o)
				o.settings = {
					yaml = {
						keyOrdering = false,
					},
				}
				return false
			end
			-- opts.setup["*"] = function(server, o)
			-- 	vim.print(server)
			-- 	vim.print(o)
			-- 	return false
			-- end
		end,
	},
}
