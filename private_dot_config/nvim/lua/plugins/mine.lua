return {

  {
    "shumphrey/fugitive-gitlab.vim",
    init = function()
      vim.g.fugitive_gitlab_domains = { "https://gitlab.sparkfabrik.com" }
    end,
    dependencies = {
      "tpope/vim-fugitive",
    },
  },

  {
    "kevinhwang91/nvim-bqf",
    event = "VimEnter",
    dependencies = {
      "junegunn/fzf",
    },
    opts = {
      func_map = {
        fzffilter = '<leader>ff'
        -- C-o toggles all
      }
    }
  },

  {
    "nvim-mini/mini.align",
    config = true,
  },

  {
    "ckolkey/ts-node-action",
    dependencies = {
      "nvim-treesitter",
      "tpope/vim-repeat",
    },
    opts = {},
    keys = {
      { "<leader>ct", function () require("ts-node-action").node_action() end, desc = "Treesitter Action" },
    },
  },

  {
    "tpope/vim-fugitive",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "Fug. status" },
      { "<leader>gd", "<cmd>Gdiffsplit<cr>", desc = "Fug. diff" },
      { "<leader>gw", "<cmd>Gwrite<cr>", desc = "Fug. write" },
      { "<leader>gb", "<cmd>Git blame -C<cr>", desc = "Fug. blame" }, -- more than one -C makes git hallucinate in my experience.
      { "<leader>gtec", "<cmd>Gtabedit @<cr>", desc = "Gtabedit @" },
      { "<leader>gtel", ":Gtabedit <C-r>+<cr>", desc = "Gtabedit clipboard sha" },
      { "<leader>gef", "<cmd>Gedit<cr>", desc = "Gedit" },
    },
    init = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>gt", group = "Git tab" },
        { "<leader>gte", group = "Git tab edit" },
      })
    end,
  },

  {
    "lfv89/vim-interestingwords",
    keys = {
      { "<leader>kk", '<cmd>call InterestingWords("n")<cr>', mode = "n", desc = "Highlight word" },
      { "<leader>kK", "<cmd>call UncolorAllWords()<cr>", mode = "n", desc = "Highlight uncolor" },
      { "<leader>kn", "<cmd>call WordNavigation(1)<cr>", mode = "n", desc = "Highlight next" },
      { "<leader>kN", "<cmd>call WordNavigation(0)<cr>", mode = "n", desc = "Highlight prev" },
      { "<leader>k", ':call InterestingWords("v")<cr>', mode = "x", desc = "Highlight word" },
    },
    init = function()
      vim.g.interestingWordsDefaultMappings = 0
      local wk = require("which-key")
      wk.add({
        { "<leader>k", group = "Highlight (for the moment)" },
      })
    end,
  },

  {
    "christoomey/vim-tmux-navigator",
    init = function()
      vim.g.tmux_navigator_preserve_zoom = 1
    end,
    keys = {
      { "<C-h>", '<cmd>TmuxNavigateLeft("n")<cr>', mode = "n", desc = "TmuxNavigateLeft" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", mode = "n", desc = "TmuxNavigateDown" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", mode = "n", desc = "TmuxNavigateUp" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", mode = "n", desc = "TmuxNavigateRight" },
      { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", mode = "n", desc = "TmuxNavigatePrevious" },
    },
  },

  {
    "nanozuki/tabby.nvim",
    config = function()
      require("tabby").setup({
        line = function(line)
          local theme = {
            fill = 'TabLineFill',
            head = 'TabLine',
            current_tab = 'TabLineSel',
            tab = 'TabLine',
            win = 'TabLine',
            tail = 'TabLine',
          }
          local function preset_tab(lline, tab)
            local hl = tab.is_current() and theme.current_tab or theme.tab
            local status_icon = { '', '󰆣' }
            return {
              lline.sep('', hl, theme.fill),
              tab.in_jump_mode() and tab.jump_key() or {
                tab.is_current() and status_icon[1] or status_icon[2],
                margin = ' ',
              },
              string.gsub(tab.name(),"%[..%]","") .. (tab.is_current() and vim.bo[0].modified and '+' or ''),
              tab.close_btn(''),
              lline.sep('', hl, theme.fill),
              hl = hl,
              margin = ' ',
            }
          end
          return {
            line.tabs().foreach(function(tab)
              return preset_tab(line, tab)
            end),
          }
        end,
        option = {
          buf_name = {
            mode= 'unique'
          }
        }
      })
    end,
  },

  {
    "mbbill/undotree",
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "UndoTree open." },
    },
  },

  {
    "AndrewRadev/linediff.vim",
    cmd = "Linediff",
  },

  {
    "phpactor/phpactor",
    ft = "php",
    keys = {
      {"<leader>pnd", ":PhpactorClassExpand<cr>", desc = "Phpactor Class Expand" },
      {"<leader>pxt", ":PhpactorExtractExpression<cr>", desc = "Phpactor Extract Expression", mode = { "n", "x" } },
    },
    init = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>p", group = "Phpactor" },
        { "<leader>pn", group = "(type d) Expand Class" },
        { "<leader>px", group = "(type t) exTract Expression" },
      })
    end,
    build = "composer install --no-dev -o"
  },

}
