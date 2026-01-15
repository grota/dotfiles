return {
  {
    "folke/sidekick.nvim",
    opts = function(_, opts)
      opts.nes = { enabled = false }
    end,
  },
  {
    "neovim/nvim-lspconfig",
    init = function()
    end,
    opts = function()
      Snacks.toggle({
        name = "Inline completions",
        get = function()
          return vim.lsp.inline_completion.is_enabled()
        end,
        set = function(state)
          vim.lsp.inline_completion.enable(state)
        end,
      }):map("<leader>uH")
      vim.defer_fn(function()
        vim.schedule(function ()
          vim.lsp.inline_completion.enable(false)
        end)
      end, 10)
    end,
  },
}
