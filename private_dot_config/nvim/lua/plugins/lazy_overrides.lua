return {
  {
    "Exafunction/codeium.nvim",
    opts = function (_, opts)
      vim.print(opts)
      opts.enable_chat = true
    end,
  },

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
  "echasnovski/mini.files",
    opts = function (_, opts)
      opts.windows.preview = false
    end,
    keys = function (_, keys)
      for i = #keys, 1, -1 do
        if keys[i][1] == "<leader>fm" then
          keys[i][1] = '<leader>e'
        end
        if keys[i][1] == "<leader>fM" then
          keys[i][1] = '<leader>E'
        end
      end
    end,
    init = function ()
      local MiniFiles = require('mini.files')
      local map_open_in = function(buf_id, lhs, create_new_window_command, desc)
        local rhs = function()
          -- Make new window and set it as target
          local new_target_window
          local windowid = MiniFiles.get_target_window();
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
    "echasnovski/mini.pairs",
    opts = function (_, opts)
      opts.mappings = {
        ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\`].', register = { cr = false } },
      }
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      for i = #opts.sources, 1, -1 do
        -- Check if the name is "buffer"
        if opts.sources[i].name == "buffer" then
          -- Change the group_index and break the loop
          opts.sources[i].group_index = 1
          break
        end
      end
    end
  },

	{
		"nvim-neo-tree/neo-tree.nvim",
		opts = {
			source_selector = {
				winbar = true,
			},
			window = {
				auto_expand_width = true,
				mappings = {
					["<cr>"] = function(state)
						local utils = require("neo-tree.utils")
						local node = state.tree:get_node()
						state.commands["open"](state)
						if utils.is_expandable(node) then
							vim.cmd.normal("j")
							vim.cmd.normal("zz")
						end
					end,
				},
			},
			filesystem = {
				commands = {
					go_up_in_tree = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" and node:is_expanded() then
							require("neo-tree.sources.filesystem").toggle_directory(state, node)
						end
						require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
            vim.cmd.normal("zz")
					end,
					go_down_in_tree = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" then
							if not node:is_expanded() then
								require("neo-tree.sources.filesystem").toggle_directory(state, node)
								vim.cmd.normal("j")
							elseif node:has_children() then
								require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
							end
              vim.cmd.normal("zz")
						else
							state.commands["open"](state)
						end
					end,
				},
				window = {
					mappings = {
						["/"] = "none",
						["f"] = "focus_preview",
						["h"] = "go_up_in_tree",
						["l"] = "go_down_in_tree",
						["z"] = "none",
						["w"] = "none",
					},
				},
				filtered_items = {
					hide_dotfiles = false,
					hide_gitignored = false,
					hide_hidden = false,
				},
			},
			buffers = {
				follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        }
			},
		},
	},

	{
		"williamboman/mason.nvim",
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

	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, o)
      o.textobjects.swap = {}
      o.textobjects.swap.enable = true
      o.textobjects.swap.swap_next = {
        ["<leader>c<Right>"] = "@parameter.inner",
      }
      o.textobjects.swap.swap_previous = {
        ["<leader>c<Left>"] = "@parameter.inner",
      }
    vim.list_extend(o.ensure_installed, {
        "go",
				"php",
				"phpdoc",
				"dockerfile",
				"twig",
        "git_rebase",
        "git_config",
        "gitattributes",
        "gitcommit",
        "gitignore",
    })
    end,
	},

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
