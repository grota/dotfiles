inoremap <buffer> kk $
iabbrev FLASE FALSE
iabbrev flase false
" LanguageClient {{{
let g:LanguageClient_diagnosticsEnable = 0
let g:LanguageClient_selectionUI = 'fzf'
let g:LanguageClient_loggingFile = expand('~/.vim/LanguageClient.log')
nnoremap <buffer> <C-]> <C-w>v :call LanguageClient#textDocument_definition()<CR>
nnoremap <buffer> <leader>lrn :call LanguageClient#textDocument_rename()<CR>
nnoremap <buffer> <leader>lcm :call LanguageClient_contextMenu()<CR>
" }}}
" configurare deoplete per /home/grota/dotfiles/vim/dotvim/bundle/autozimu_LanguageClient-neovim/rplugin/python3/deoplete/sources/LanguageClientSource.py
" ddev issue
