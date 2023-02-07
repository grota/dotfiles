vim.cmd('source ' .. vim.fn.stdpath("config") .. '/source_vimrc.vim')

vim.o.inccommand='split'

vim.api.nvim_create_autocmd({"TextYankPost"}, {
  pattern = {"*"},
  callback = function()
    require'vim.highlight'.on_yank({
      timeout = 100,
      higroup="IncSearch",
    })
  end,
})

local nvim_lsp = require('lspconfig')

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- print(vim.inspect(client.server_capabilities))
  -- print(vim.inspect(client.resolved_capabilities))
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  --Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<Cmd>vertical split<CR><Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>vertical split<CR><Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', '<leader>D', '<Cmd>vertical split<CR><Cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<leader>K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<Cmd>vertical split<CR><Cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<Cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<leader>rn', '<Cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<leader>ca', '<Cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<Cmd>vertical split<CR><Cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<leader>d', '<Cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<Cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<Cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<leader>dl', '<Cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap("n", '<leader>fb', '<Cmd>lua vim.lsp.buf.formatting()<CR>', opts)
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- local phpservers = { "phpactor" }
-- local phpservers = { "intelephense" }
local phpservers = { "intelephense", "phpactor" }
for _, lsp in ipairs(phpservers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    filetypes = { "php", "module", "theme", "profile", "inc" },
    flags = {
      debounce_text_changes = 150,
    },
    settings = {
      intelephense = {
        files = {
          maxSize = 500000,
          associations = { "*.php", "*.module", "*.theme", "*.profile", "*.inc" },
          exclude = {
            "**/build/phpqa/**",
            "**/.git/**",
            "**/.svn/**",
            "**/.hg/**",
            "**/CVS/**",
            "**/.DS_Store/**",
            "**/node_modules/**",
            "**/bower_components/**",
            "**/vendor/**/{Tests,tests}/**",
            "**/.history/**",
            "**/vendor/**/vendor/**"
          }
        }
      }
    }
  }
end
nvim_lsp.tsserver.setup {
    on_attach = on_attach,
}

nvim_lsp.gopls.setup{
    on_attach = on_attach,
}
nvim_lsp.terraform_lsp.setup{
    on_attach = on_attach,
}
nvim_lsp.terraformls.setup{
    on_attach = on_attach,
}
nvim_lsp.ccls.setup{
    on_attach = on_attach,
}


require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
  indent = {
    enable = true
  },
  rainbow = {
    enable = true
  }
}
vim.cmd [[highlight IndentBlanklineIndent1 guibg=#1f1f1f gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent2 guibg=#1a1a1a gui=nocombine]]

require("indent_blankline").setup {
    char = "",
    char_highlight_list = {
        "IndentBlanklineIndent1",
        "IndentBlanklineIndent2",
    },
    space_char_highlight_list = {
        "IndentBlanklineIndent1",
        "IndentBlanklineIndent2",
    },
    show_trailing_blankline_indent = false,
}

require("telescope").setup()
require('telescope').load_extension('fzf')
