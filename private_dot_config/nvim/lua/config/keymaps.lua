-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local function map(mode, lhs, rhs, opts)
	local keys = require("lazy.core.handler").handlers.keys
	---@cast keys LazyKeysHandler
	-- do not create the keymap if a lazy keys handler exists
	if not keys.active[keys.parse({ lhs, mode = mode }).id] then
		vim.keymap.set(mode, lhs, rhs, opts)
	end
end

-- Clean LazyVim's keymaps
-- vim.keymap.del("n", "<C-h>")
-- vim.keymap.del("n", "<C-j>")
-- vim.keymap.del("n", "<C-k>")
-- vim.keymap.del("n", "<C-l>")
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
vim.keymap.del("n", "<leader>bb")
vim.keymap.del("n", "<leader>`")
vim.keymap.del({ "n", "x" }, "gw")
vim.keymap.del({ "n", "x", "o" }, "n")
vim.keymap.del({ "n", "x", "o" }, "N")
vim.keymap.del("n", "<leader>gg")
vim.keymap.del("n", "<leader>gG")
vim.keymap.del("n", "<leader>ww")
vim.keymap.del("n", "<leader>wd")
vim.keymap.del("n", "<leader>-")
vim.keymap.del("n", "<leader>|")
vim.keymap.del("n", "<leader>w|")
vim.keymap.del("n", "<leader>fn")
vim.keymap.del("n", "<leader>l")

local wk = require("which-key")
wk.register({
	["<leader>v"] = { name = "Neovim rc stuff" },
	["<leader>y"] = { name = "Custom yanks" },
})

map("n", "<leader>L", "<cmd>:Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>vv", "<cmd>e $MYVIMRC<Cr>", { desc = "Edit $MYVIMRC" })
map("n", "<leader>vld", "<cmd>e ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/<Cr>", { desc = "Edit LazyVim dir" })

map("n", "<M-1>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map("n", "<M-2>", "<cmd>tabnext<cr>", { desc = "Previous tab" })
map("n", "<M-!>", "<cmd>tabmove -1<cr>", { desc = "Move tab left" })
map("n", "<M-@>", "<cmd>tabmove +1<cr>", { desc = "Move tab right" })

-- map("n", "<Tab>", "<C-w>w", { desc = "Next window." })
-- map("n", "<S-Tab>", "<C-w>W", { desc = "Previous window." })
map("n", "<C-w>{", "<C-w>R", { desc = "Rotate windows upwards/leftwards." })
map("n", "<C-w>}", "<C-w>r", { desc = "Rotate windows downwards/rightwards." })
map("n", "<leader>w\\", "<C-W>v", { desc = "Split window right" })

map("n", "<F1>", "<C-w>o", { desc = "Current win only." })
map("n", "<F2>", "<C-w>c", { desc = "Close window." })
map("n", "<F3>", "<C-w>T", { desc = "Move current window to new tab page." })
-- map("n", "<F5>", "<cmd>tabedit<cr>", { desc = "New tab" })

map(
	"n",
	"gV",
	'"`[" . strpart(getregtype(), 0, 1) . "`]"',
	{ expr = true, desc = "Visually select last edited/pasted." }
)

map("n", "<leader>yf", '<cmd>let @+=expand("%")<CR>:echo "copied " . expand("%")<CR>', { desc = "Copy full path" })
map("n", "<leader>yo", '<cmd>let @+=expand("%:t")<CR>:echo "copied " . expand("%:t")<CR>', { desc = "Copy filename" })
map(
	"n",
	"<leader>yO",
	'<cmd>let @+=expand("%:t:r")<CR>:echo "copied " . expand("%:t:r")<CR>',
	{ desc = "Copy filename (no extension)" }
)
map("n", "<leader>yp", '<cmd>let @+=expand("%:h")<CR>:echo "copied " . expand("%:h")<CR>', { desc = "Copy path" })
map("n", "<leader>yw", function()
	local pwd = vim.loop.cwd()
	vim.fn.setreg("+", pwd, "c")
	vim.cmd.echo('"copied ' .. pwd .. '"')
end, { desc = "Copy pwd" })

map("n", "<leader><F5>", "<cmd>help grota<cr>", { desc = "Personal nvim notes" })
map("n", "<leader>ww", "<cmd>pwd<cr>", { desc = "PWD" })

map("n", "<leader><tab>c", [[:tabedit <C-r>+<cr>]], { desc = "Open clipboard in new tab" })

map(
	"n",
	"<leader>gh-",
	"<cmd>Gitsigns toggle_deleted<cr><cmd>Gitsigns toggle_word_diff<cr><cmd>Gitsigns toggle_linehl<cr>",
	{ desc = "Gitsign extra info toggle" }
)
-- Search visually selected text (slightly better than builtins in Neovim>=0.8)
map("x", "*", [[y/\V<C-R>=escape(@", '/\')<CR><CR>]])
map("x", "#", [[y?\V<C-R>=escape(@", '?\')<CR><CR>]])

map("n", "<leader>uC", "<Cmd>setlocal cursorcolumn! cursorcolumn?<CR>", { desc = "Toggle 'cursorcolumn'" })

map("i", "<M-h>", "<Left>", { desc = "Left" })
map("i", "<M-j>", "<Down>", { desc = "Down" })
map("i", "<M-k>", "<Up>", { desc = "Up" })
map("i", "<M-l>", "<Right>", { desc = "Right" })

-- Add empty lines before and after cursor line
map("n", "[<space>", function()
	local count = vim.v.count1
	return require("gitsigns.repeat").mk_repeatable(function()
		vim.cmd([[call append(line('.') - 1, repeat([''], ]] .. count .. [[))]])
	end)()
end, { desc = "Put empty line above" })
map("n", "]<space>", function()
	local count = vim.v.count1
	return require("gitsigns.repeat").mk_repeatable(function()
		vim.cmd([[call append(line('.'), repeat([''], ]] .. count .. [[))]])
	end)()
end, { desc = "Put empty line below" })

map({ "n", "x", "o" }, "[S", function()
	MiniAi.move_cursor("left", "a", "S", { n_times = vim.v.count1 })
end, { desc = "Go left to statement" })

-- Inner line
map("x", "iL", [[<Esc>^vg_]], { noremap = true, desc = "Inner line." })
map("o", "iL", [[<cmd>normal! ^vg_<CR>]], { noremap = true, desc = "Inner line." })
