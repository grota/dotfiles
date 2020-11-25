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

" unmappings {{{
" IndexedSearch: unmap stupid mappings that start with \, use g/ in case
"unmap \\
"unmap \/
"}}}

" CHANGE CASE {{{
"nnoremap U gUiWw
"}}}
