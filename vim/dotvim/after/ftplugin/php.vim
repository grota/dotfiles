inoremap <buffer> kk $
" vim-php-namespace {{{
noremap <Leader>u :call PhpInsertUse()<CR>
noremap <Leader>e :call PhpExpandClass()<CR>
"}}}
" phpactor {{{
nnoremap <Leader>mm :call phpactor#ContextMenu()<CR>
nnoremap <Leader>tt :call phpactor#Transform()<CR>
" Extract expression (normal mode)
nnoremap <silent><Leader>ex :call phpactor#ExtractExpression(v:false)<CR>
" Extract expression from selection
xnoremap <silent><Leader>ex:<C-U>call phpactor#ExtractExpression(v:true)<CR>
" Extract method from selection
xnoremap <silent><Leader>em :<C-U>call phpactor#ExtractMethod()<CR>
" Extract expression from selection
xnoremap <silent><Leader>ee :<C-U>call phpactor#ExtractExpression(v:true)<CR>
" }}}
