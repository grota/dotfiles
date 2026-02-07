return {
  {
    "snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          keys = {
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = " ", key = "r", desc = "Recent files (local)", action = "<leader>fr" },
            { icon = " ", key = "o", desc = "Recent files (global)", action = "<leader>fo" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "c", desc = "Nvim Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "m", desc = "Global Marks", action = "<leader>mm" },
            { icon = "󰒲 ", key = "L", desc = "Load Nvim Session", action = "<leader>ml" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
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
