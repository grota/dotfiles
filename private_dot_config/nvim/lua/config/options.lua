-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.autowrite = vim.api.nvim_get_option_info("autowrite").default
vim.opt.inccommand = "split"
vim.opt.scrolloff = 1
if vim.opt.shada:get()[2] == "'100" then
	vim.opt.shada:append("'2000")
	vim.opt.shada:remove("'100")
end
vim.o.listchars = "tab:▸\\ ,trail:·,extends:❯,nbsp:·,precedes:❮"
