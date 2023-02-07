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
--map("n", "<leader>p", function() vim.pretty_print(require('lazy.core.config').plugins) end, { desc = "Print Lazy Specs" })
map("n", "<leader>vv", "<cmd>e $MYVIMRC<Cr>", { desc = "Edit $MYVIMRC" })
map("n", "<leader>vld", "<cmd>e ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/<Cr>", { desc = "Edit LazyVim dir" })

vim.keymap.del("n", "<C-h>")
vim.keymap.del("n", "<C-j>")
vim.keymap.del("n", "<C-k>")
vim.keymap.del("n", "<C-l>")
-- lazyvim would remap H and L to bprevious and bnext.
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
-- Clean the "Switch to Other Buffer" (I use <C-6>)
vim.keymap.del("n", "<leader>bb")
vim.keymap.del("n", "<leader>`")

vim.keymap.del({ "n", "x" }, "gw")

vim.keymap.del({ "n", "x", "o" }, "n")
vim.keymap.del({ "n", "x", "o" }, "N")
vim.keymap.del("n", "<leader>gg")
vim.keymap.del("n", "<leader>gG")
vim.keymap.del("n", "<leader>ww")
vim.keymap.del("n", "<leader>wd")

map('n', '<M-1>', '<cmd>tabprevious<cr>', {desc = 'Previous tab'})
map('n', '<M-2>', '<cmd>tabnext<cr>', {desc = 'Previous tab'})
map('n', '<M-!>', '<cmd>tabmove -1<cr>', {desc = 'Move tab left'})
map('n', '<M-@>', '<cmd>tabmove +1<cr>', {desc = 'Move tab right'})
map('n', '<Tab>', '<C-w>w', {desc = 'Next window.'})
map('n', '<S-Tab>', '<C-w>W', {desc = 'Previous window.'})

map('n', '<C-w>{', '<C-w>R', {desc = 'Rotate windows upwards/leftwards.'})
map('n', '<C-w>}', '<C-w>r', {desc = 'Rotate windows downwards/rightwards.'})

map('n', '<F1>', '<C-w>o', {desc = 'Current win only.'})
map('n', '<F2>', '<C-w>c', {desc = 'Close window.'})
map('n', '<F3>', '<C-w>T', {desc = 'Move current window to new tab page.'})

map('n', 'gV', '`[v`]', {desc = 'Visually select last edited/pasted.'})

map('n', '<leader>Fs', '<cmd>Git<cr>', {desc = 'Fugitive status'})
map('n', '<leader>Fw', '<cmd>Gw<cr>', {desc = 'Fugitive write'})
map('n', '<leader>Fb', '<cmd>Git blame<cr>', {desc = 'Fugitive blame'})

map('n', '<leader>yf', '<cmd>let @+=expand("%")<CR>:echo "copied " . expand("%")<CR>', {desc='Copy full path'})
map('n', '<leader>yo', '<cmd>let @+=expand("%:t")<CR>:echo "copied " . expand("%:t")<CR>', {desc='Copy filename'})
map('n', '<leader>yO', '<cmd>let @+=expand("%:t:r")<CR>:echo "copied " . expand("%:t:r")<CR>', {desc='Copy filename (no extension)'})
map('n', '<leader>yp', '<cmd>let @+=expand("%:h")<CR>:echo "copied " . expand("%:h")<CR>', {desc='Copy path'})
