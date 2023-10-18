-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_gitrebase", { clear = true }),
	pattern = { "gitrebase" },
	callback = function()
		vim.keymap.set("n", "S", "<cmd>Cycle<Cr>", { desc = "Cycle" })
    require("persistence").stop()
	end,
})
local grota_quickfix_group = vim.api.nvim_create_augroup("grota_quickfix", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
	group = grota_quickfix_group,
	pattern = { "qf" },
	callback = function()
		vim.keymap.set("n", "<leader>uR", function()
			vim.fn.setqflist(vim.tbl_map(function(entry)
				return vim.tbl_extend("force", entry, {
					text = vim.api.nvim_buf_get_lines(entry.bufnr, entry.lnum - 1, entry.lnum, false)[1],
				})
			end, vim.fn.getqflist()))
		end, { desc = "Refresh quickfix", buffer = true })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_gitcommit", { clear = true }),
	pattern = { "gitcommit" },
	callback = function()
		vim.keymap.set(
			"n",
			"<leader>d",
			"<cmd>DiffGitCached<Cr><cmd>wincmd L<Cr>",
			{ desc = "Show diff", buffer = true }
		)
    require("persistence").stop()
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("grota_php", { clear = true }),
	pattern = { "php" },
	callback = function()
		vim.keymap.set("i", "kk", "$", { desc = "imap kk=$ for php", buffer = true })
	end,
})
