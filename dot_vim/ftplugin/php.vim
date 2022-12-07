" We provide the ctags based approach here which is useful until the php LS is done indexing.
nnoremap <leader>gd :vertical stjump <C-r><C-w><CR>
" phpactor {{{
nnoremap <Leader>mm :PhpactorContextMenu<CR>
nnoremap <Leader>tt :PhpactorTransform<CR>
nnoremap <Leader>e :PhpactorClassExpand<CR>
nnoremap <Leader>u :PhpactorImportClass<CR>
nnoremap <Leader>ua :PhpactorImportMissingClasses<CR>
" Extract expression from selection
xnoremap <silent><Leader>ee :<C-u>PhpactorExtractExpression<CR>
" Extract method from selection
xnoremap <silent><Leader>em :<C-u>PhpactorExtractMethod<CR>
" }}}
setlocal keywordprg=pman
setlocal foldmethod=expr
setlocal foldexpr=nvim_treesitter#foldexpr()
