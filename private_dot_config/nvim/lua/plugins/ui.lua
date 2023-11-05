return {

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_c, { 'w:quickfix_title' })
      opts.sections.lualine_c[4] = {'filename', path = 1 }
    end
	},

	{
		-- Remove the keys part, I only want to use <M-n> and <M-p>
		-- And I also don't want to lose the ]] and [[ mappings from core ft.
		"RRethy/vim-illuminate",
		keys = function(_, _)
			return {}
		end,
		opts = {
			filetype_overrides = {
				-- There seems to be a bug in one of the 2 lsp I use in supporting the next word (<M-n>)
				php = {
					providers = { "treesitter" },
				},
			},
		},
		config = function(_, opts)
			require("illuminate").configure(opts)
		end,
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
              height = '10%',
            },
            win_options = {
              wrap = true,
            }
          }
        },

      }
    }
	},

}
