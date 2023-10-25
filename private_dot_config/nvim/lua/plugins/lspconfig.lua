return {
	{
		"neovim/nvim-lspconfig",
		init = function()
			local keys = require("lazyvim.plugins.lsp.keymaps").get()
			keys[#keys + 1] = { "<leader>cl", false }
			keys[#keys + 1] = { "<leader>cL", "<cmd>LspInfo<cr>", desc = "Lsp Info" }
		end,
    ---@param opts PluginLspOpts
		opts = function(_, opts)
      -- return true if you don't want a server to be setup with lspconfig
      ---@param o lspconfig.options.clangd
			opts.setup.clangd = function(_, o)
				o.capabilities.offsetEncoding = { "utf-16" }
				return false
			end
      ---@param o lspconfig.options.yamlls
			opts.setup.yamlls = function(_, o)
				o.settings.yaml.keyOrdering = false
				return false
			end
      ---@param o lspconfig.options.intelephense
      opts.setup.intelephense = function(_, o)
        o.settings.intelephense.files.associations = { "*.php", "*.module", "*.inc" }
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
