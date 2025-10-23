return {
  {
    "folke/sidekick.nvim",
    opts = function(_, opts)
      vim.g.sidekick_nes = false
    end,
    keys = {
      {
        "<leader>an",
        function ()
          vim.g.sidekick_nes = not vim.g.sidekick_nes
          vim.print(vim.g.sidekick_nes and 'NES Enabled' or 'NES disabled')
        end,
        desc = "Toggle GH NES"
      }
    }
  }
}
