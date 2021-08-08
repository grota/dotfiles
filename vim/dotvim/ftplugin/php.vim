" Since <C-]> is overriden in vim/dotvim/after/ftplugin/php.vim we provide the
" ctags based approach here which is useful until the php LS is done indexing.
nnoremap <leader>gd :vertical stjump <C-r><C-w><CR>
" phpactor {{{
nnoremap <Leader>mm :PhpactorContextMenu<CR>
nnoremap <Leader>tt :PhpactorTransform<CR>
noremap <Leader>e :PhpactorClassExpand<CR>
noremap <Leader>u :PhpactorImportClass<CR>
noremap <Leader>ua :PhpactorImportMissingClasses<CR>
" Extract expression from selection
xnoremap <silent><Leader>ee :<C-u>PhpactorExtractExpression<CR>
" Extract method from selection
xnoremap <silent><Leader>em :<C-u>PhpactorExtractMethod<CR>
" }}}
setlocal keywordprg=pman
