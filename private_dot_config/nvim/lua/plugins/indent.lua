-- see lua/config/lazy.lua
return {
  {
    "nvim-mini/mini.indentscope",
    opts = function (_, opts)
      opts.draw = {}
      opts.draw.delay = 10
      opts.draw.animation = require('mini.indentscope').gen_animation.none()
    end,
  },
}
