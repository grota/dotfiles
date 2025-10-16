local function get_current_word_or_visual_selection()
  local word
  local visual = vim.fn.mode() == "v"

  if visual == true then
    local saved_reg = vim.fn.getreg("v")
    vim.cmd([[noautocmd silent normal "vy]])
    local sele = vim.fn.getreg("v")
    vim.fn.setreg("v", saved_reg)
    word = sele
  else
    word = vim.fn.expand("<cword>")
  end
  return word
end

local actions = require("telescope.actions")
local myactions = require("grota.telescope.actions")

local lsp_symbol_types = require("lazyvim.config").get_kind_filter()
-- telescope_default_vimgrep_arguments = {
--   "rg",
--   "--color=never",
--   "--no-heading",
--   "--with-filename",
--   "--line-number",
--   "--column",
--   "--smart-case"
-- }
local telescope_default_vimgrep_arguments = require("telescope.config").values.vimgrep_arguments
local opts_hidden_no_dot_git = {
  "--hidden",
  "-g=!.git/**",
}
local opts_no_ignore = {
  "--no-ignore",
  "--no-ignore-parent",
}
local vimgrep_hidden_no_dot_git = vim.deepcopy(telescope_default_vimgrep_arguments)
vim.list_extend(vimgrep_hidden_no_dot_git, opts_hidden_no_dot_git)
local vimgrep_arguments_for_all = vim.deepcopy(vimgrep_hidden_no_dot_git)
vim.list_extend(vimgrep_arguments_for_all, opts_no_ignore)
-- vim.print(vimgrep_arguments_for_all)
local find_all_files_cmd = {
  "rg",
  "--files",
  "--color",
  "never",
}
vim.list_extend(find_all_files_cmd, opts_hidden_no_dot_git)
vim.list_extend(find_all_files_cmd, opts_no_ignore)
local git_grep_vimgrep_args = {
  "git",
  "--no-pager",
  "grep",
  "--no-color",
  "--line-number",
  "--column",
  "-I", -- no binary files
}
local git_grep_ignore_case_vimgrep_args = vim.deepcopy(git_grep_vimgrep_args)
vim.list_extend(git_grep_ignore_case_vimgrep_args, { "--ignore-case" })
local telescope_builtins = require("telescope.builtin")

return {
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      opts.defaults.mappings.i["<a-i>"] = false
      opts.defaults.mappings.i["<a-h>"] = false
      opts.defaults.mappings.i["<C-j>"] = actions.move_selection_next
      opts.defaults.mappings.i["<C-k>"] = actions.move_selection_previous
      opts.defaults.mappings.i["<c-t>"] = myactions.select_tab -- C needs to stay lowercase because it's like that in Lazyvim
      opts.defaults.mappings.i["<C-v>"] = myactions.select_vertical
      -- section only slightly modified to pass func directly to have telescope's which-key with something.
      -- opts.defaults.mappings.i["<C-S-t>"] = require("trouble.providers.telescope").open_with_trouble
      opts.defaults.mappings.i["<C-Down>"] = actions.cycle_history_next
      opts.defaults.mappings.i["<C-Up>"] = actions.cycle_history_prev
      opts.defaults.mappings.i["<C-f>"] = actions.preview_scrolling_down
      opts.defaults.mappings.i["<C-b>"] = actions.preview_scrolling_up
      opts.defaults.mappings.i["<C-o>"] = actions.complete_tag
      opts.defaults.mappings.i["<C-l>"] = actions.send_to_loclist + actions.open_loclist
      opts.defaults.mappings.i["<M-l>"] = actions.send_selected_to_loclist + actions.open_loclist
      -- I prefer https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#mapping-c-u-to-clear-prompt
      -- C-d wiped for symmetry.
      opts.defaults.mappings.i["<C-u>"] = false
      opts.defaults.mappings.i["<C-d>"] = false
      opts.defaults.wrap_results = true
      opts.defaults.layout_config = {
        horizontal = {
          width = 0.99,
          prompt_position = "top",
        },
      }
      opts.pickers = {
        buffers = {
          mappings = {
            i = {
              ["<C-d>"] = actions.delete_buffer
            },
          },
        },
        lsp_references = {
          show_line = false,
        },
        lsp_implementations = {
          show_line = false,
        },
      }
    end,
    keys = function()
      -- <leader>st is used by folke/todo-comments.nvim
      -- <leader>sn is used by folke/noice.nvim
      return {
        -- START Grepping section. ggs,ggi,gG
        {
          "<leader>ggs",
          function()
            telescope_builtins.live_grep({
              prompt_title = "Git Grep sensitive",
              vimgrep_arguments = git_grep_vimgrep_args,
              default_text = get_current_word_or_visual_selection(),
              debounce = 300,
            })
          end,
          desc = "git grep case sensitive",
        },
        {
          "<leader>ggi",
          function()
            telescope_builtins.live_grep({
              prompt_title = "Git Grep in-sensitive",
              vimgrep_arguments = git_grep_ignore_case_vimgrep_args,
              default_text = get_current_word_or_visual_selection(),
              debounce = 300,
            })
          end,
          desc = "git grep case insensitive",
        },
        {
          "<leader>gga",
          function()
            telescope_builtins.live_grep({
              prompt_title = "RipGrep all",
              vimgrep_arguments = vimgrep_arguments_for_all,
              default_text = get_current_word_or_visual_selection(),
              debounce = 600,
            })
          end,
          desc = "RipGrep all",
        },
        -- START files section sf,sF
        { "<leader>ff", "<cmd>Telescope git_files<cr>", desc = "Git Files" },
        {
          "<leader>fF",
          function()
            telescope_builtins.find_files({
              prompt_title = "Search All files",
              find_command = find_all_files_cmd,
            })
          end,
          desc = "All Files",
        },
        -- START oldfiles section so,sO
        {
          "<leader>fo",
          function()
            telescope_builtins["oldfiles"]({
              prompt_title = "Oldfiles local",
              cwd_only = true,
            })
          end,
          desc = "Recent local",
        },
        {
          "<leader>fO",
          function()
            telescope_builtins["oldfiles"]({
              prompt_title = "Oldfiles global",
            })
          end,
          desc = "Recent global",
        },
        -- START lsp symbols ss,sS
        {
          "<leader>ss",
          function()
            telescope_builtins.lsp_document_symbols({
              symbols = lsp_symbol_types,
              symbol_width = 60,
            })
            vim.defer_fn(function()
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-u>', true, true, true), 'n', false)
            end, 200)
          end,
          desc = "Search Symbol (Document)",
        },
        {
          "<leader>sS",
          function()
            telescope_builtins.lsp_workspace_symbols({
              symbols = lsp_symbol_types,
              symbol_width = 60,
            })
          end,
          desc = "Search Symbol (Workspace)",
        },
        -- START telescope prefixed.
        {
          "<leader>tpl",
          function()
            telescope_builtins["builtin"]({ default_text = "lsp_" })
          end,
          desc = "Telescope lsp_*",
        },
        {
          "<leader>tpp",
          function()
            telescope_builtins["commands"]({ default_text = "Phpactor" })
          end,
          mode = { "n", "x" },
          desc = "Telescope Phpactor*",
        },
        -- START various section.
        {
          "<leader>th",
          function()
            telescope_builtins["keymaps"]({
              default_text = "'Telescope !'TelescopeFuzzyCommandSearch ",
            })
          end,
          desc = "Telescope help",
        },
        { "<leader>,", function()
          telescope_builtins["buffers"]({
            show_all_buffers = true,
            layout_config = {
              preview_width = 0,
            },
          })
        end, desc = "Switch Buffer" },
        { "<leader>tr", "<cmd>Telescope resume<cr>", desc = "Telescope Resume" },
        { "<leader>gS", "<cmd>Telescope git_status<CR>", desc = "Telescope git status" },
        { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Telescope search buffer" },
        { "<leader>sC", "<cmd>Telescope command_history<cr>", desc = "Command History" },
        { "<leader>sK", "<cmd>Telescope keymaps<cr>", desc = "Key Maps" },
        { "<leader>sw", "<cmd>Telescope windows<cr>", desc = "Window list" },
      }
    end,
    dependencies = {
      "kyoh86/telescope-windows.nvim",
    },
    config = function(_, opts)
      local t = require("telescope")
      t.setup(opts)
      t.load_extension("windows")
      t.load_extension("telescope-tabs")
    end,
    init = function()
      local wk = require("which-key")
      wk.add({
      { "<leader>gg", group = "Git grep" },
      { "<leader>t", group = "Telescope" },
      { "<leader>tp", group = "Telescope prefix" },
      })
    end,
  },

  {
    "LukasPietzschmann/telescope-tabs",
        dependencies = {
      "nvim-telescope/telescope.nvim",
        },
    keys = {
      {
        "<leader><tab>s",
        function ()
          require('telescope-tabs').list_tabs()
        end,
        desc = "Tabs list"
      },
      { "<leader><tab><tab>", function () require('telescope-tabs').go_to_previous() end, desc = "Tab previous" },
    }
  },
}
