local M = {}

local conf = require("telescope.config").values
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local Path = require "plenary.path"
local actions = require "telescope.actions"

-- Copied and modified from telescope.nvim/lua/telescope/builtin/__internal.lua
-- No need for locals nor numberical marks.
M.marks = function()
  local global_marks = {
    items = vim.fn.getmarklist(),
    name_func = function(mark, _)
      -- get buffer name if it is opened, otherwise get file name
      local bufname = vim.api.nvim_get_mark(mark, {})[4]
      return Path:new(bufname):make_relative(vim.loop.cwd())
    end,
  }
  local marks_table = {}
  local all_marks = {}
  all_marks = { global_marks }

  for _, cnf in ipairs(all_marks) do
    for _, v in ipairs(cnf.items) do
      -- strip the first single quote character
      local mark = string.sub(v.mark, 2, 3)
      local _, lnum, col, _ = unpack(v.pos)
      local name = cnf.name_func(mark, lnum)
      -- same format to :marks command
      local line = string.format("%s %6d %4d %s", mark, lnum, col - 1, name)
      local row = {
        line = line,
        lnum = lnum,
        col = col,
        filename = vim.fs.normalize(v.file),
      }
      -- only uppercase
      if mark:match "%u" then
        table.insert(marks_table, row)
      end
    end
  end

  pickers
    .new({}, {
      prompt_title = "Marks",
      finder = finders.new_table {
        results = marks_table,
        entry_maker = make_entry.gen_from_marks({}),
      },
      previewer = conf.grep_previewer({}),
      sorter = conf.generic_sorter({}),
      push_cursor_on_edit = true,
      push_tagstack_on_edit = true,
      attach_mappings = function(_, map)
        map("i", "<C-d>", actions.delete_mark)
        return true
      end,
    })
    :find()
end

return M
