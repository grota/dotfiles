-- To see the list of installed yazi plugins run in shell: ya pkg list

require("bookmarks"):setup({
  last_directory = { enable = false, persist = true, mode="dir" },
  persist = "all",
  desc_format = "full",
  file_pick_mode = "parent",
  custom_desc_input = false,
  show_keys = true,
  notify = {
    enable = true,
    timeout = 3,
    message = {
      new = "New bookmark '<key>' -> '<folder>'",
      delete = "Deleted bookmark in '<key>'",
      delete_all = "Deleted all bookmarks",
    },
  },
})

require("full-border"):setup()
