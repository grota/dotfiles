return {
	{
		"echasnovski/mini.ai",
		opts = function(_, opts)
			local ai = require("mini.ai")
			opts.custom_textobjects.S = ai.gen_spec.treesitter({
				a = { "@statement.outer", "@function.outer" },
				i = { "@statement.outer", "@function.inner" },
			}, {})
		end,
    keys = {
      {
        "[S",
        function() MiniAi.move_cursor("left", "a", "S", { n_times = vim.v.count1 }) end,
        desc = "Go left to statement",
        mode = { 'n', 'o', 'x' }
      },
    }
	},

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_c, { 'w:quickfix_title' })
      opts.sections.lualine_c[4] = {'filename', path = 1 }
    end
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
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        '<leader>gh-',
        "<cmd>Gitsigns toggle_deleted<cr><cmd>Gitsigns toggle_word_diff<cr><cmd>Gitsigns toggle_linehl<cr>",
        { desc = "Gitsign extra info toggle" },
        mode = 'n',
      },
    },
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
					end,
					go_down_in_tree = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" then
							if not node:is_expanded() then
								require("neo-tree.sources.filesystem").toggle_directory(state, node)
								vim.cmd.normal("j")
								vim.cmd.normal("zz")
							elseif node:has_children() then
								require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
								vim.cmd.normal("zz")
							end
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
		"nvimtools/none-ls.nvim",
		dependencies = {
			"mason.nvim",
			"ckolkey/ts-node-action",
		},
		opts = function(_, o)
			local nls = require("null-ls")
			vim.list_extend(o.sources, {
				nls.builtins.code_actions.shellcheck,
				nls.builtins.code_actions.ts_node_action,
			})
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

	{
		-- this simply did not work out for me, I need a real tabline not a bufferline.
		"akinsho/bufferline.nvim",
		enabled = false,
	},

	{
		"nvim-pack/nvim-spectre",
		enabled = false,
	},
}
