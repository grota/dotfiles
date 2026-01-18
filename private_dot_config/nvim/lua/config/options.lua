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
vim.g.snacks_animate = false
vim.o.wrap = true
-- vim.g.lazyvim_python_lsp = 'basedpyright'

-- LazyVim at the time of this writing https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/config/options.lua#L57
-- does not set vim.o.clipboard when in SSH (at the end of the day I think it's mainly for performance reasons)
-- but, for comfort, I want it even in ssh, and since we do that we also need to set g:clipboard below,
-- see nvim's runtime/autoload/provider/clipboard.vim and runtime/lua/vim/provider/health.lua
vim.o.clipboard = 'unnamedplus'
-- BufEnter event because vim.g.termfeatures is set very late and asyncronously, see runtime/plugin/osc52.lua.
-- Even using TermResponse did not work.
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    if vim.g.clipboard then
      return
    end
    -- Calling vim.fn['provider#clipboard#Executable']() here wreaks havok with the rest of nvim.
    if vim.g.termfeatures and vim.g.termfeatures.osc52 then
      vim.g.clipboard = 'osc52'
    elseif os.getenv('TMUX') then
      vim.g.clipboard = 'tmux'
    end
  end,
})
