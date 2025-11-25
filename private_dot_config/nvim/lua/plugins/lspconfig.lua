return {
	{
		"neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
		opts = function(_, opts)
      opts.inlay_hints.enabled = false
      -- return true if you don't want a server to be setup with lspconfig
      ---@param o lspconfig.options.clangd
			opts.setup.clangd = function(_, o)
				o.capabilities.offsetEncoding = { "utf-16" }
				return false
			end
      ---@param o lspconfig.options.yamlls
			opts.setup.yamlls = function(_, o)
        o.settings = o.settings or {}
        o.settings.yaml = o.settings.yaml or {}
				o.settings.yaml.keyOrdering = false
				return false
			end
      ---@param o lspconfig.options.intelephense
      opts.setup.intelephense = function(_, o)
        o.settings = o.settings or {}
        o.settings.intelephense = o.settings.intelephense or {}
        o.settings.intelephense.files = o.settings.intelephense.files or {}
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
