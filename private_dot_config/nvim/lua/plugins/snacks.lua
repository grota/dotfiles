return {
  {
    "snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          keys = {
            { icon = " ", key = "s", desc = "(s) Restore Session", section = "session" },
            { icon = "󱋣 ", key = "r", desc = "(r) Recent files (local)", action = "<leader>fr" },
            { icon = "󰎕 ", key = "o", desc = "(o) Recent files (global)", action = "<leader>fo" },
            { icon = " ", key = "n", desc = "(n) New File", action = ":ene | startinsert" },
            { icon = " ", key = "z", desc = "(z) Chezmoi", action = '<leader>sz' },
            { icon = " ", key = "x", desc = "(x) Lazy Extras", action = ":LazyExtras" },
            { icon = "󰒲 ", key = "l", desc = "(l) Lazy", action = ":Lazy" },
            { icon = "󰚝 ", key = "m", desc = "(m) Global Marks", action = "<leader>mm" },
            { icon = " ", key = "L", desc = "(L) Load Nvim Session", action = "<leader>ml" },
            { icon = " ", key = "q", desc = "(q) Quit", action = ":qa" },
          }
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 0, padding = 1  },
          { section = "projects", limit=5},
        }
      }
    }

  }
}
