" vim:ft=vim:foldmethod=marker:foldcolumn=3

" PhpFolds {{{
" Here, with augroup SetPhpFolds we are adding ourself to the end of
" the SetPhpFolds group defind in phpfolding.vim.
" The other autocmds in phpfolding.vim use BufReadPost * so we
" cannot use autocmd FileType php because we get overridden.
" We also need to set foldlevel=99 (all open) because the plugin
" closes all the folds it creates by default.
augroup SetPhpFolds
    autocmd BufReadPost *
                \ if &filetype == "php" |
                \ setlocal foldcolumn=2 |
                \ setlocal foldlevel=99 |
                \ endif
augroup end
"}}}

" Tabularize additions {{{
if !exists(':Tabularize')
  finish " Tabular.vim wasn't loaded
endif
let s:save_cpo = &cpo
set cpo&vim
AddTabularPattern! equalgt /^[^=>]*\zs=>/
let &cpo = s:save_cpo
unlet s:save_cpo
"}}}

" set here to override the one in the marvim plugin
"vnoremap <F2> :norm!@q<CR>

" unmappings {{{
" IndexedSearch: unmap stupid mappings that start with \, use g/ in case
unmap \\
unmap \/

" Bclose, unmap default mappings
"nunmap <leader>bd
"}}}

nnoremap \\ ``
" set by garbas' snipmate
sunmap \

" CHANGE CASE {{{
nnoremap U gUiWw
"}}}
" SnipMate {{{
" the S-C-B mappings shadow the C-B ones, due to the fact that they are
" unrecognizable to vim.
" 1st step: unmap the backwards shadow in insert mode.
iunmap <S-C-B>
" 2nd step: map correctly the <C-B> to what we want.
inoremap <silent> <C-B> <c-g>u<c-r>=snipMate#TriggerSnippet()<cr>
" 3rd step: unmap in select mode, due to shadowing, 1 unmap is enough.
sunmap <C-B>
"}}}
" PreciseJump {{{
nunmap _F
vunmap _F
ounmap _F
nunmap _f
vunmap _f
ounmap _f
omap - v:call PreciseJumpF(-1, -1, 0)<cr>
"}}}
