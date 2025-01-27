local M = {}

M.SetFirstUnmarkedUppercaseMark = function ()
  local cursor = vim.api.nvim_win_get_cursor(0)
  for i = string.byte('A'), string.byte('Z') do
    local mark = vim.fn.getpos("'" .. string.char(i))
    if mark ~= nil and mark[1] == 0 then
      vim.api.nvim_buf_set_mark(0, string.char(i), cursor[1], cursor[2], {})
      vim.api.nvim_echo({{'Mark set: ' .. string.char(i), 'None'}}, true, {})
      return
    end
  end

  vim.api.print("All uppercase marks have been set.")
end

return M
