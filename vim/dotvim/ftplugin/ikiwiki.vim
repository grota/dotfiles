function! IkiGrotaConvertAndOpen ()
    echom '/tmp/'.expand('%')
    let l:sourcemkd = fnamemodify(expand('%'), ':p')
    let l:htmlfile = fnamemodify(l:sourcemkd, ":t:r").'.html'
    let l:destination_html = '/tmp/'.l:htmlfile
    execute ':silent !'.' markdown '.l:sourcemkd.' > '.l:destination_html
    execute ':silent !'.' xdg-open 2> /dev/null "'.l:destination_html.'"'
    redraw!
endfunction


nnoremap <buffer> <Tab>      :IkiNextWikiLink<CR>
nnoremap <buffer> <S-tab>    :IkiPrevWikiLink<CR>
nnoremap <buffer> <CR>       :IkiJumpOrCreatePageCW<CR>
nnoremap <buffer> <BS>       <C-O>
nnoremap <silent> <buffer> <Leader>wc :call IkiGrotaConvertAndOpen()<CR>
