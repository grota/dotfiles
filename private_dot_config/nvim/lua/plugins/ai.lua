return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    -- type #buffer:<tab> for a popup window.
    -- or #url:<tab> for an input box to enter a URL and get a summary of the page.
    -- you can confirm a tool call with just a submit.
    keys = function (_, keys)
      -- "<leader>ac" to toggle the chat window, instead of "<leader>aa" which is reserved for sidekick toggle cli.
      for _, key in ipairs(keys) do
        if type(key) == "table" and key[1] == "<leader>aa" then
          key[1] = "<leader>ac"
        end
      end
    end,
    opts = function (_, opts)
      opts.model = 'gpt-5-mini'
      -- the defaults are awful.
      opts.mappings = {
        close = {
          normal = '<C-q>',
          insert = '<C-q>',
        },
        submit_prompt = {
          normal = '<C-o>',
          insert = '<C-o>',
        },
        reset = {
          normal = '<C-f>',
          insert = '<C-f>',
        },
      }
    end
  },
  {
    "folke/sidekick.nvim",
    -- opts = function(_, opts)
      -- Inline completions: Quick, as-you-type suggestions.
      -- NES: Larger refactorings and multi-line changes after you pause
      -- Type some code and pause - watch for Next Edit Suggestions appearing. "<leader>uN" to toggle.
      -- opts.nes = { enabled = false }
    -- end,
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

      -- vim.defer_fn(function()
      --   vim.schedule(function ()
      --     vim.lsp.inline_completion.enable(false)
      --   end)
      -- end, 10)
    end,
  },
}
