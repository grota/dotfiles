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
        background = { -- :h background
          light = "latte",
          dark = "mocha",
        },
        color_overrides = {
          mocha = {
            base = "#000000",
            mauve = "#FFB703",
            -- lavender = "#6C584C",
            lavender = "#DEB49B",
            peach = "#A2D2FF",
            text = "#F2F5E0",
          },
        },
        dim_inactive = {
          enabled = true,
          shade = "dark",
          percentage = 0.85,
        },
        highlight_overrides = {
          mocha = function(mocha)
            return {
              Search = { bg = "#875f00", fg = "black" },
              CurSearch = { bg = "#dfaf00", fg = "black" },
              -- DiffChange = { bg = "#5f005f" },
              -- DiffText = { bg = "#005f00" },
              -- DiffAdd = { bg = "#002000" },
              -- DiffDelete = { bg = "#5f0000" },
              -- diffAdded = { fg = "#00aa00" },
              -- diffRemoved = { fg = "#dd0022" },
              FlashLabel = {
                fg = '#5555ff',
                bg = '#550000',
                bold = true,
              },
              FlashMatch = {
                fg = mocha.green,
              },
              FlashCurrent = {
                fg = mocha.sky,
              },
            }
          end,
        },
        integrations = {
          gitsigns = true,
          leap = true,
          markdown = true,
          mason = true,
          neotree = true,
          noice = true,
          lsp_trouble = true,
          illuminate = true,
          which_key = true,
          treesitter = true,
          flash = false,
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { "italic" },
              hints = { "italic" },
              warnings = { "italic" },
              information = { "italic" },
            },
            underlines = {
              errors = { "underline" },
              hints = { "underline" },
              warnings = { "underline" },
              information = { "underline" },
            },
          },
        },
      })
      -- vim.cmd.colorscheme("catppuccin-mocha")
    end,
    --enabled = false,
  },
}
