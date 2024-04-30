vim.opt.termguicolors = true

vim.opt.autowrite = vim.api.nvim_get_option_info2("autowrite", {}).default
vim.opt.inccommand = "split"
vim.opt.scrolloff = 1
if vim.opt.shada:get()[2] == "'100" then
	vim.opt.shada:append("'2000")
	vim.opt.shada:remove("'100")
end
vim.o.listchars = "tab:-󰌒,trail:·,extends:❯,nbsp:·,precedes:❮"
vim.o.breakindent = true
vim.o.virtualedit = "block" -- Allow going past the end of line in visual block mode
vim.o.pumblend = 10 -- Make builtin completion menus slightly transparent
vim.o.foldlevelstart = 99
vim.o.foldmethod = "syntax"
vim.opt.conceallevel = 0

vim.g.autoformat = false
