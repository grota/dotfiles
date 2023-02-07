return {

	{
		-- this simply did not work out for me, I need a real tabline not a bufferline.
		"akinsho/bufferline.nvim",
		enabled = false,
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
          ["<cr>"] = function (state)
            local utils = require("neo-tree.utils")
            local node = state.tree:get_node()
            state.commands["open"](state)
            if utils.is_expandable(node) then
              vim.cmd.normal('j')
            end
          end,
        },
      },
      filesystem = {
        bind_to_cwd = true,
        commands = {
          go_up_in_tree = function(state)
            local node = state.tree:get_node()
            if node.type == 'directory' and node:is_expanded() then
              require'neo-tree.sources.filesystem'.toggle_directory(state, node)
            end
            require'neo-tree.ui.renderer'.focus_node(state, node:get_parent_id())
          end,
          go_down_in_tree = function(state)
            local node = state.tree:get_node()
            if node.type == 'directory' then
              if not node:is_expanded() then
                require'neo-tree.sources.filesystem'.toggle_directory(state, node)
                vim.cmd.normal('j')
              elseif node:has_children() then
                require'neo-tree.ui.renderer'.focus_node(state, node:get_child_ids()[1])
              end
            else
              state.commands["open"](state)
            end
          end
        },
        window = {
          mappings = {
            ["/"] = 'none',
            ["f"] = 'focus_preview',
            ["h"] = 'go_up_in_tree',
            ["l"] = 'go_down_in_tree',
          },
        },
        filtered_items = {
          hide_dotfiles = false,
        },
      },
      buffers = {
        follow_current_file = true,
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require("telescope.actions")
      opts.defaults.mappings.i["<C-j>"] = 'move_selection_next'
      opts.defaults.mappings.i["<C-k>"] = 'move_selection_previous'
      opts.defaults.mappings.i["<c-t>"] = actions.select_tab -- C needs to stay lowercase because it's like that in Lazyvim
      -- section only slightly modified to pass func directly to have telescope's which-key with something.
      opts.defaults.mappings.i["<C-S-t>"] = require("trouble.providers.telescope").open_with_trouble
      opts.defaults.mappings.i["<C-Down>"] = require("telescope.actions").cycle_history_next
      opts.defaults.mappings.i["<C-Up>"] = require("telescope.actions").cycle_history_prev
    end,
    keys = {
      {'<leader>tt', '<cmd>Telescope<cr>', desc = "Open Telescope."},
      { "<leader>fr", false },
      { "<leader>frg", "<cmd>Telescope oldfiles<cr>", desc = "Recent global" },
      { "<leader>frl", function() require("telescope.builtin")['oldfiles']{cwd_only=true} end, desc = "Recent local" },
    },
    dependencies = {
      "tsakirist/telescope-lazy.nvim",
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make'
      }
    },
    config = function(_, opts)
      local t = require('telescope')
      t.setup(opts)
      t.load_extension('lazy')
      t.load_extension('fzf')
    end
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
				"flake8",
			}
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"bash",
				"help",
				"html",
				"javascript",
				"json",
				"jsonc",
				"lua",
				"markdown",
				"markdown_inline",
				"query",
				"regex",
				"tsx",
				"typescript",
				"vim",
				"yaml",
				"php",
				"phpdoc",
				"dockerfile",
				"twig",
			},
		},
	},

	{
		"goolord/alpha-nvim",
		opts = function(_, opts)
			local logo = [[




███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ]]
			opts.section.header.val = vim.split(logo, "\n")
		end,
	},
}
