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
    "gbprod/yanky.nvim",
    keys = function ()
      local yanky_keys = require('lazyvim.plugins.extras.coding.yanky')[1]['keys']
      if yanky_keys[1]['desc'] == "Open Yank History" and yanky_keys[1][1] == "<leader>p" then
        table.remove(yanky_keys, 1)
      else
        error("[GROTA] Could not find right yanky key")
      end
      table.insert(
        yanky_keys,
        {"<leader>yh", function() require("telescope").extensions.yank_history.yank_history({ }) end, desc = "Open Yank History" }
      )
      return yanky_keys
    end
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
