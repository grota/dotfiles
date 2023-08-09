-- Kill arch default behavior of making pacman-installed global
-- Arch Linux vim packages work in neovim
-- since we want a vim/neovim separate conf and plugins anyway
-- and I install plugins at user level.
-- https://archlinux.org/packages/community/x86_64/neovim/
vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")

require("config.lazy")
