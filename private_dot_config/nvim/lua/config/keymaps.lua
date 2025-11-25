-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local function map(mode, lhs, rhs, opts)
	local keys = require("lazy.core.handler").handlers.keys
	---@cast keys LazyKeysHandler
	-- do not create the keymap if a lazy keys handler exists
	if not keys.active[keys.parse({ lhs, mode = mode }).id] then
		vim.keymap.set(mode, lhs, rhs, opts)
	end
end

-- Clean LazyVim's keymaps
vim.keymap.del("n", "<S-h>") -- was prev buffer
vim.keymap.del("n", "<S-l>") -- was next buffer
vim.keymap.del("n", "<leader>bb") -- was Switch to Other Buffer
vim.keymap.del("n", "<leader>`") -- was Switch to Other Buffer
vim.keymap.del({ "n", "x", "o" }, "n") -- was https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.del({ "n", "x", "o" }, "N") -- was https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n

vim.keymap.del("n", "<leader>-") -- was Split window below
vim.keymap.del("n", "<leader>|") -- was Split window right
vim.keymap.del("n", "<leader>fn") -- was new file

local wk = require("which-key")
wk.add({
  { "<leader>v", group = "Neovim rc stuff" },
  { "<leader>y", group = "Custom yanks" },
})

map("n", "<leader>vv", "<cmd>e $MYVIMRC<Cr>", { desc = "Edit $MYVIMRC" })
map("n", "<leader>vld", "<cmd>e ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/<Cr>", { desc = "Edit LazyVim dir" })

map("n", "<C-w>{", "<C-w>R", { desc = "Rotate windows upwards/leftwards." })
map("n", "<C-w>}", "<C-w>r", { desc = "Rotate windows downwards/rightwards." })
map("n", "<leader>w\\", "<C-W>v", { desc = "Split window right" })
map("n", "<leader>wo", "<C-W>o", { desc = "Only window", remap = true })

map("n", "<F1>", "<C-w>o", { desc = "Current win only." })
map("n", "<F2>", "<C-w>c", { desc = "Close window." })
map("n", "<F3>", "<C-w>T", { desc = "Move current window to new tab page." })

map(
	"n",
	"gV",
	'"`[" . strpart(getregtype(), 0, 1) . "`]"',
	{ expr = true, desc = "Visually select last edited/pasted." }
)

map("x", ".", ":normal .<CR>", { desc = "Do . on all selected line" })

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
map("n", "<leader><F4>", "<cmd>pwd<cr>", { desc = "PWD" })

map("n", "<leader><tab>c", [[:tabedit <C-r>+<cr>]], { desc = "Open clipboard in new tab" })
map("n", "<leader><tab>n", "<cmd>tabnew<cr>", { desc = "New Tab" })

map("n", "<M-1>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map("n", "<M-2>", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<M-!>", "<cmd>tabmove -1<cr>", { desc = "Move tab left" })
map("n", "<M-@>", "<cmd>tabmove +1<cr>", { desc = "Move tab right" })

-- Search visually selected text (slightly better than builtins in Neovim>=0.9.1) runtime/lua/vim/_editor.lua
-- The <C-r>='' is a noop but without it for some filetypes there's a timing issue that breaks the <C-r>= substitution.
map("x", "*", [[y/\V<C-r>=''<CR><C-r>=substitute(escape(@", '/\'), '\n', '\\n', 'g')<CR><CR>]], { noremap = true })
map("x", "#", [[y?\V<C-r>=''<CR><C-R>=substitute(escape(@", '?\'), '\n', '\\n', 'g')<CR><CR>]], { noremap = true })

map("n", "<leader>uC", "<Cmd>setlocal cursorcolumn! cursorcolumn?<CR>", { desc = "Toggle 'cursorcolumn'" })

map("i", "<M-h>", "<Left>", { desc = "Left" })
map("i", "<M-j>", "<Down>", { desc = "Down" })
map("i", "<M-k>", "<Up>", { desc = "Up" })
map("i", "<M-l>", "<Right>", { desc = "Right" })

-- Add empty lines before and after cursor line
map("n", "[<space>", function()
	local count = vim.v.count1
	return require("grota.repeat").mk_repeatable(function()
		vim.cmd([[call append(line('.') - 1, repeat([''], ]] .. count .. [[))]])
	end)()
end, { desc = "Put empty line above" })
map("n", "]<space>", function()
	local count = vim.v.count1
	return require("grota.repeat").mk_repeatable(function()
		vim.cmd([[call append(line('.'), repeat([''], ]] .. count .. [[))]])
	end)()
end, { desc = "Put empty line below" })

-- Inner line
map("x", "iL", [[<Esc>^vg_]], { noremap = true, desc = "Inner line." })
map("o", "iL", [[<cmd>normal! ^vg_<CR>]], { noremap = true, desc = "Inner line." })

-- it's just easier that way :)
map("i", "<C-c>", "<ESC>", { noremap = true })

-- Session stuff
wk.add({
  { "<leader>m", group = "Marks and Sessions" },
})
local session_dir = vim.fn.stdpath("data") .. "/sessions/"

map("n", "<leader>ms", function()
  local filename = vim.fn.input({
    prompt = "Session name: ",
    default = session_dir,
    completion = "file",
  })
  vim.cmd('mksession! ' .. filename)
end, { desc = "Save session" })

map("n", "<leader>ml", function()
  local myactions = require("grota.telescope.actions")
  require("telescope.builtin").find_files({
    search_dirs = { session_dir },
    cwd = session_dir,
    previewer = false,
    attach_mappings = function(_, maptelescope)
      maptelescope("i", "<CR>", myactions.source_entry)
      maptelescope("i", "<C-d>", myactions.remove_selected_files)
      return true -- We want to map default_mappings.
    end,
  })
end, { desc = "Load session" })

map('n', '<leader>ma', function () require("grota.marks").SetFirstUnmarkedUppercaseMark() end, { desc = "Mark add" })
map('n', '<leader>mm', function() require('grota.telescope').marks() end, { desc = "Telescope marks" })

map('i', '<C-o>', '<C-\\><C-o>', { noremap = true, desc = "C-o without moving cursor" })

map("n", "<leader>bd", "<cmd>:bd<cr>", { desc = "Delete Buffer" })
map("n", "<leader>bD", function() Snacks.bufdelete() end, { desc = "Delete Buffer and Window" })

if LazyVim.has('mini.files') then
  map('n', "<leader>e", "<leader>fm", {desc="Open mini.files", remap=true})
end

vim.keymap.set('n', '<C-]>', function()
  -- split vertically
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-w>v', true, false, true), 'n', false)
  -- perform the real builtin Ctrl-] action
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-]>', true, false, true), 'n', false)
end, { noremap = true, silent = true })
