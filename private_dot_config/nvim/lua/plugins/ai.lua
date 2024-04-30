return {
  {
    "jackMort/ChatGPT.nvim",
    keys ={
      { '<leader>cc', "<cmd>ChatGPT<CR>", mode = 'n', desc = 'ChatGPT' },
      { '<leader>ce', "<cmd>ChatGPTEditWithInstruction<CR>", mode = {'n', 'v'}, desc = 'ChatGPT Edit' },
      { '<leader>cR', ":ChatGPTRun ", mode = {'n', 'v'}, desc = 'ChatGPT run' },
    },
    config = function()
      -- ~/.local/share/nvim/lazy/ChatGPT.nvim/lua/chatgpt/config.lua
      local opts = require("chatgpt.config").defaults()
      opts.openai_params.max_tokens = 3500
      opts.openai_params.model = "gpt-4-turbo"
      opts.openai_edit_params.model = "gpt-4-turbo"
      opts.chat.keymaps.close = "<Esc>"
      opts.edit_with_instructions.keymaps.close = "<Esc>"
      require("chatgpt").setup(opts)
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    },
    event = "VeryLazy",
  },

}
