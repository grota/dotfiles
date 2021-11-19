" expands to path of the current file
cnoremap <expr> ./. expand('%:p:h').'/'
"cnoremap <expr> ./. getcmdtype() == ':' ? expand('%:p:h').'/' : './.'
cnoremap <C-P> <Up>
cnoremap <C-N> <Down>
cnoremap <C-J> <S-Down>
cnoremap <C-K> <S-Up>

" Pieces taken from https://github.com/houtsnip/vim-emacscommandline.git
cnoremap <C-A> <Home>

cnoremap <C-H> <C-\>e<SID>BackwardWord()<CR>
cnoremap <C-L> <C-\>e<SID>ForwardWord()<CR>
cnoremap <M-h> <Left>
cnoremap <M-l> <Right>
" C-w/C-d delete WORDS/words LEFT  of the cursor
cnoremap <C-W> <C-\>e<SID>DeleteBackwardsToWhiteSpace()<CR>
cnoremap <C-D> <C-\>e<SID>BackwardKillWord()<CR>
" M-w/M-d delete WORDS/words RIGHT of the cursor
cnoremap <M-w> <C-\>e<SID>DeleteForwardToWhiteSpace()<CR>
cnoremap <M-d> <C-\>e<SID>KillWord()<CR>
cnoremap <C-Y> <C-\>e<SID>Yank()<CR>
" as builtin, but with history
cnoremap <C-U> <C-\>e<SID>BackwardKillLine()<CR>

function! <SID>ForwardWord()
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    if (l:roc =~ '\v^\s*\w')
        let l:rem = matchstr(l:roc, '\v^\s*\w+')
    elseif (l:roc =~ '\v^\s*[^[:alnum:]_[:blank:]]')
        let l:rem = matchstr(l:roc, '\v^\s*[^[:alnum:]_[:blank:]]+')
    else
        call setcmdpos(strlen(getcmdline()) + 1)
        return getcmdline()
    endif
    call setcmdpos(strlen(l:loc) + strlen(l:rem) + 1)
    return getcmdline()
endfunction

function! <SID>BackwardWord()
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    if (l:loc =~ '\v\w\s*$')
        let l:rem = matchstr(l:loc, '\v\w+\s*$')
    elseif (l:loc =~ '\v[^[:alnum:]_[:blank:]]\s*$')
        let l:rem = matchstr(l:loc, '\v[^[:alnum:]_[:blank:]]+\s*$')
    else
        call setcmdpos(1)
        return getcmdline()
    endif
    let @c = l:rem
    call setcmdpos(strlen(l:loc) - strlen(l:rem) + 1)
    return getcmdline()
endfunction

function! <SID>DeleteForwardToWhiteSpace()
    call <SID>saveUndoHistory(getcmdline(), getcmdpos())
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    echom "roc=".l:roc
    if (l:roc =~ '\v^\S\s*')
        let l:rem = matchstr(l:roc, '\v^\S+\s*')
        "echom 'rem='.l:rem
    elseif (l:roc =~ '\v^\s+$')
        let @c = l:roc
        call setcmdpos(1)
        return l:loc
    else
        return getcmdline()
    endif
    let @c = l:rem
    let l:ret = l:loc . strpart(l:roc, strlen(l:rem))
    echom 'ret='.l:ret
    call <SID>saveUndoHistory(l:ret, getcmdpos())
    return l:ret
endfunction

function! <SID>DeleteBackwardsToWhiteSpace()
    call <SID>saveUndoHistory(getcmdline(), getcmdpos())
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    if (l:loc =~ '\v\S\s*$')
        let l:rem = matchstr(l:loc, '\v\S+\s*$')
    elseif (l:loc =~ '\v^\s+$')
        let @c = l:loc
        call setcmdpos(1)
        return l:roc
    else
        return getcmdline()
    endif
    let @c = l:rem
    let l:pos = getcmdpos() - strlen(l:rem)
    let l:ret = strpart(l:loc, 0, strlen(l:loc) - strlen(l:rem)) . l:roc
    call <SID>saveUndoHistory(l:ret, l:pos)
    call setcmdpos(l:pos)
    return l:ret
endfunction

function! <SID>BackwardKillWord()
    " Do same as in-built Ctrl-W, except assign deleted text to @c
    call <SID>saveUndoHistory(getcmdline(), getcmdpos())
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    if (l:loc =~ '\v\w\s*$')
        let l:rem = matchstr(l:loc, '\v\w+\s*$')
    elseif (l:loc =~ '\v[^[:alnum:]_[:blank:]]\s*$')
        let l:rem = matchstr(l:loc, '\v[^[:alnum:]_[:blank:]]+\s*$')
    elseif (l:loc =~ '\v^\s+$')
        let @c = l:loc
        call setcmdpos(1)
        return l:roc
    else
        return getcmdline()
    endif
    let @c = l:rem
    let l:pos = getcmdpos() - strlen(l:rem)
    let l:ret = strpart(l:loc, 0, strlen(l:loc) - strlen(l:rem)) . l:roc
    call <SID>saveUndoHistory(l:ret, l:pos)
    call setcmdpos(l:pos)
    return l:ret
endfunction

function! <SID>KillWord()
    call <SID>saveUndoHistory(getcmdline(), getcmdpos())
    let l:loc = strpart(getcmdline(), 0, getcmdpos() - 1)
    let l:roc = strpart(getcmdline(), getcmdpos() - 1)
    if (l:roc =~ '\v^\s*\w')
        let l:rem = matchstr(l:roc, '\v^\s*\w+')
    elseif (l:roc =~ '\v^\s*[^[:alnum:]_[:blank:]]')
        let l:rem = matchstr(l:roc, '\v^\s*[^[:alnum:]_[:blank:]]+')
    elseif (l:roc =~ '\v^\s+$')
        let @c = l:roc
        return l:loc
    else
        return getcmdline()
    endif
    let @c = l:rem
    let l:ret = l:loc . strpart(l:roc, strlen(l:rem))
    call <SID>saveUndoHistory(l:ret, getcmdpos())
    return l:ret
endfunction

function! <SID>BackwardKillLine()
    call <SID>saveUndoHistory(getcmdline(), getcmdpos())
    let l:cmd = getcmdline()
    let l:rem = strpart(l:cmd, 0, getcmdpos() - 1)
    if ('' != l:rem)
        let @c = l:rem
    endif
    let l:ret = strpart(l:cmd, getcmdpos() - 1)
    call <SID>saveUndoHistory(l:ret, 1)
    call setcmdpos(1)
    return l:ret
endfunction

function! <SID>Yank()
    let l:cmd = getcmdline()
    call setcmdpos(getcmdpos() + strlen(@c))
    return strpart(l:cmd, 0, getcmdpos() - 1) . @c . strpart(l:cmd, getcmdpos() - 1)
endfunction

let s:oldcmdline = [ ]
function! <SID>saveUndoHistory(cmdline, cmdpos)
    if len(s:oldcmdline) == 0 || a:cmdline != s:oldcmdline[0][0]
        call insert(s:oldcmdline, [ a:cmdline, a:cmdpos ], 0)
    else
        let s:oldcmdline[0][1] = a:cmdpos
    endif
    if len(s:oldcmdline) > 100
        call remove(s:oldcmdline, 100)
    endif
endfunction
