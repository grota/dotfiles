return {

  -- {
  --   -- fzf-lua defaults ~/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/defaults.lua
  --   -- LazyVim conf ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua
  --   "ibhagwan/fzf-lua",
  --   opts = function(_, opts)
  --     opts.winopts.fullscreen = true
  --
  --     local fzf = require("fzf-lua")
  --     local config = fzf.config
  --     local actions = fzf.actions
  --     config.defaults.actions.files["ctrl-t"] = actions.file_tabedit
  --     config.defaults.winopts.preview.horizontal = "right:50%"
  --   end,
  --   keys = {
  --     { "<leader>sv", "", desc = "+various"},
  --       {
  --         "<leader>svl",
  --         "<cmd>FzfLua builtin query='lsp<cr>",
  --         desc = "fzf-lua lsp_*",
  --       },
  --   }
  -- }
}
