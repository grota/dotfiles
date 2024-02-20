local M = {}

local transform_mod = require("telescope.actions.mt").transform_mod
local action_state = require "telescope.actions.state"
local state = require "telescope.state"
local telescope_pickers = require "telescope.pickers"
local action_set = require "telescope.actions.set"

local get_entries = function(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local multi_selection = picker:get_multi_selection()
  return #multi_selection > 1 and multi_selection or { action_state.get_selected_entry() }
end

M.source_entry = function(prompt_bufnr)
  telescope_pickers.on_close_prompt(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  vim.cmd.source(entry[1])
end

M.remove_selected_files = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  -- callback can return false when some error occurs and entry should not be deleted.
  current_picker:delete_selection(function(selection)
    local res, msg = os.remove(selection[1])
    if res == nil then
      vim.print("Error removing file: " .. msg)
      return false
    else
      return true
    end
  end)
end

local set_status_with_close_func = function(prompt_bufnr, orig_status, orig_picker, close_func)
  orig_status.picker = orig_picker
  orig_picker.close_windows = close_func
  state.set_status(prompt_bufnr, orig_status)
end

--- works around telescope's api (bad hack)
local get_action_set_edit_with_multi_support = function(command)
  return function(prompt_bufnr)
    local orig_status = state.get_status(prompt_bufnr)
    local orig_picker = orig_status.picker
    local orig_close_windows = orig_picker.close_windows

    for _, entry in ipairs(get_entries(prompt_bufnr)) do
      state.set_global_key("selected_entry", entry)
      set_status_with_close_func(prompt_bufnr, orig_status, orig_picker, function() end)
      action_set.edit(prompt_bufnr, command)
    end

    set_status_with_close_func(prompt_bufnr, orig_status, orig_picker, orig_close_windows)
    telescope_pickers.on_close_prompt(prompt_bufnr)
  end
end

--- Like actions.select_tab but supports multiple selections
M.select_tab = get_action_set_edit_with_multi_support(action_state.select_key_to_edit_key("tab"))
--- Like actions.select_vertical but supports multiple selections
M.select_vertical = get_action_set_edit_with_multi_support(action_state.select_key_to_edit_key("vertical"))

M = transform_mod(M)
return M
