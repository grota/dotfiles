return {
  {
    'Exafunction/codeium.vim',
    init = function ()
      vim.g.codeium_no_map_tab = true
    end,
    keys ={
      { '<M-y>', function () return vim.fn['codeium#Accept']() end, mode = 'i', desc = 'Codeium Accept', expr = true },
    },
    event = 'VeryLazy',
  },
  {
    "jackMort/ChatGPT.nvim",
    keys ={
      { '<leader>cc', "<cmd>ChatGPT<CR>", mode = 'n', desc = 'ChatGPT' },
      { '<leader>ce', "<cmd>ChatGPTEditWithInstruction<CR>", mode = {'n', 'v'}, desc = 'ChatGPT Edit' },
      { '<leader>cR', ":ChatGPTRun ", mode = {'n', 'v'}, desc = 'ChatGPT run' },
    },
    config = function()
      require("chatgpt").setup({
        chat = {
          keymaps = {
            close = { "<Esc>" },
            -- yank_last = "<C-y>",
            -- yank_last_code = "<C-k>",
            -- scroll_up = "<C-u>",
            -- scroll_down = "<C-d>",
            -- new_session = "<C-n>",
            -- cycle_windows = "<Tab>",
            -- cycle_modes = "<C-f>",
            -- select_session = "<Space>",
            -- rename_session = "r",
            -- delete_session = "d",
            -- draft_message = "<C-d>",
            -- toggle_settings = "<C-o>",
            -- toggle_message_role = "<C-r>",
            -- toggle_system_role_open = "<C-s>",
            -- stop_generating = "<C-x>",
          },
        },
        edit_with_instructions = {
          keymaps = {
            close = "<Esc>",
            -- accept = "<C-y>",
            -- toggle_diff = "<C-d>",
            -- toggle_settings = "<C-o>",
            -- cycle_windows = "<Tab>",
            use_output_as_input = "<C-t>",
          },
        },
        popup_layout = {
          default = "right",
        }
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    },
    event = "VeryLazy",
  },
}
