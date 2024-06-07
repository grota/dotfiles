-- some stuff that I might remove later depending on how I feel about it.
return {

  {
    "echasnovski/mini.ai",
    opts = function(_, opts)
      local ai = require("mini.ai")
      opts.custom_textobjects.S = ai.gen_spec.treesitter({
        a = { "@statement.outer", "@function.outer" },
        i = { "@statement.outer", "@function.inner" },
      }, {})
    end,
    keys = {
      {
        "[S",
        function() MiniAi.move_cursor("left", "a", "S", { n_times = vim.v.count1 }) end,
        desc = "Go left to statement",
        mode = { 'n', 'o', 'x' }
      },
    }
  },

	-- {
	-- 	-- Remove the keys part, I only want to use <M-n> and <M-p>
	-- 	-- And I also don't want to lose the ]] and [[ mappings from core ft.
	-- 	"RRethy/vim-illuminate",
	-- 	keys = function(_, _)
	-- 		return {}
	-- 	end,
	-- 	opts = {
	-- 		filetype_overrides = {
	-- 			-- There seems to be a bug in one of the 2 lsp I use in supporting the next word (<M-n>)
	-- 			php = {
	-- 				providers = { "treesitter" },
	-- 			},
	-- 		},
	-- 	},
	-- 	config = function(_, opts)
	-- 		require("illuminate").configure(opts)
	-- 	end,
	-- },

}
