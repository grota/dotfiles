-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_gitrebase", { clear = true }),
	pattern = { "gitrebase" },
	callback = function()
		vim.keymap.set("n", "S", "<cmd>Cycle<Cr>", { desc = "Cycle" })
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_gitcommit", { clear = true }),
	pattern = { "gitcommit" },
	callback = function()
		vim.keymap.set("n", "<leader>d", "<cmd>DiffGitCached<Cr><cmd>wincmd L<Cr>", { desc = "Show diff" })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_php", { clear = true }),
	pattern = { "php" },
	callback = function()
		vim.keymap.set("i", "kk", "$", { desc = "imap kk=$ for php", buffer = true })
	end,
})
