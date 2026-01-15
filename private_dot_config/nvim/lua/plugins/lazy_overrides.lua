return {
  {
    "folke/flash.nvim",
    opts = {
      modes = {
        search = {
          enabled = false,
        },
      },
    },
  },

  {
  "nvim-mini/mini.files",
    opts = function (_, opts)
      opts.windows.preview = false
    end,

    init = function ()
      local MiniFiles = require('mini.files')
      local map_open_in = function(buf_id, lhs, create_new_window_command, desc)
        local rhs = function()
          -- Make new window and set it as target
          local new_target_window
          local windowid = MiniFiles.get_explorer_state().target_window
          if windowid == nil then
            return
          end
          vim.api.nvim_win_call(windowid, function()
            vim.cmd(create_new_window_command)
            new_target_window = vim.api.nvim_get_current_win()
          end)

          MiniFiles.set_target_window(new_target_window)
          MiniFiles.go_in({close_on_file = true})
        end

        vim.keymap.set('n', lhs, rhs, { buffer = buf_id, desc = desc })
      end

      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniFilesBufferCreate',
        callback = function(args)
          local buf_id = args.data.buf_id
          map_open_in(buf_id, '<C-x>', 'belowright horizontal split', 'Open in horizontal split')
          map_open_in(buf_id, '<C-v>', 'belowright vertical split', 'Open in vertical split')
          map_open_in(buf_id, '<C-t>', 'tabe', 'Open in new tab')
        end,
      })
    end,
  },

  {
    "nvim-mini/mini.pairs",
    opts = function (_, opts)
      opts.mappings = {
        ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\`].', register = { cr = false } },
      }
    end,
  },

  {
    "mason-org/mason.nvim",
    opts = function(_, o)
      o.ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "phpactor",
        "intelephense",
        "lua-language-server",
      }
    end,
  },

  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   opts = function(_, o)
  --     o.textobjects.swap = {}
  --     o.textobjects.swap.enable = true
  --     o.textobjects.swap.swap_next = {
  --       ["<leader>c<Right>"] = "@parameter.inner",
  --     }
  --     o.textobjects.swap.swap_previous = {
  --       ["<leader>c<Left>"] = "@parameter.inner",
  --     }
  --     vim.list_extend(o.ensure_installed, {
  --       "go",
  --       "php",
  --       "phpdoc",
  --       "dockerfile",
  --       "twig",
  --       "git_rebase",
  --       "git_config",
  --       "gitattributes",
  --       "gitcommit",
  --       "gitignore",
  --     })
  --   end,
  -- },

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_c, { 'w:quickfix_title' })
      opts.sections.lualine_c[4] = {'filename', path = 1 }
    end
  },

  {
    "folke/noice.nvim",
    keys = {
      { "<leader>snD", "<cmd>Noice disable<cr>", desc = "Noice disable" },
      { "<leader>snE", "<cmd>Noice enable<cr>", desc = "Noice enable" },
      {
        "<M-Enter>",
        function()
          require("noice").redirect(vim.fn.getcmdline())
        end,
        mode = "c",
        desc = "Redirect Cmdline",
      }, -- <S-Enter> does not work on my term emulator.
    },
    opts = {
      messages = {
        view_search = 'mini',
      },
      routes = {
        {
          view = "confirm",
          filter = {
            any = {
              {
                event = "msg_show",
                kind = "confirm",
                find = "oto_definition", -- hack to target PhpactorContextMenu.
              },
              {
                event = "msg_show",
                kind = "confirm",
                find = "Transform", -- hack to target PhpactorTransform.
              }
            }
          },
          opts = {
            size = {
              width = '80%',
              height = '20%',
            },
            win_options = {
              wrap = true,
            }
          }
        },

      }
    }
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = function (_, opts)
      opts.max_lines = 5
    end,
  },

}
