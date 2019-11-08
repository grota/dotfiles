" Since <C-]> is overriden in vim/dotvim/after/ftplugin/php.vim we provide the
" ctags based approach here which is useful until the php LS is done indexing.
nnoremap <leader>gd :vertical stjump <C-r><C-w><CR>
" vim-php-namespace {{{
noremap <Leader>u :call PhpInsertUse()<CR>
noremap <Leader>e :call PhpExpandClass()<CR>
"}}}
" phpactor {{{
nnoremap <Leader>mm :call phpactor#ContextMenu()<CR>
nnoremap <Leader>tt :call phpactor#Transform()<CR>
" Extract expression (normal mode)
nnoremap <silent><Leader>ex :call phpactor#ExtractExpression(v:false)<CR>
" Extract method from selection
xnoremap <silent><Leader>em :<C-U>call phpactor#ExtractMethod()<CR>
" Extract expression from selection
xnoremap <silent><Leader>ee :<C-U>call phpactor#ExtractExpression(v:true)<CR>
" }}}
