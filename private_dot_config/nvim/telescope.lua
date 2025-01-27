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
          desc = "Telescope git grep case sensitive",
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
          desc = "Telescope git grep case insensitive",
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
          desc = "Telescope RipGrep all",
        },
        -- START files section sf,sF
        {
          "<leader>sF",
          function()
            telescope_builtins.find_files({
              prompt_title = "Search All files",
              find_command = find_all_files_cmd,
            })
          end,
          desc = "Telescope All Files",
        },
      }
    end,
  },
}
