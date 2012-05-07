if exists("+showtabline")
    function! GrotaTabLine()
        let s = ''
        let wn = ''
        let t = tabpagenr()
        let i = 1
        while i <= tabpagenr('$')
            let buflist = tabpagebuflist(i)
            let winnr = tabpagewinnr(i)
            let s .= '%' . i . 'T'
            let wn = tabpagewinnr(i,'$')
            let s .= (i == t ? '%#TabLineSel#' : '%#TabLine#')
            let s .= '['
            let bufnr = buflist[winnr - 1]
            let file = bufname(bufnr)
            let buftype = getbufvar(bufnr, 'buftype')
            if buftype == 'nofile'
                if file =~ '\/.'
                    let file = substitute(file, '.*\/\ze.', '', '')
                endif
            else
                let file = fnamemodify(file, ':p:t')
            endif
            if file == ''
                let file = '_________'
            endif
            let s .= file
            let s .= (&modified ? ' ' : '')
            let s .= (i == t ? '%#TabLineModifiedMark#%m%#TabLineSel#' : '')
            let s .= ']'
            let s .= '%#TabLineFill# '
            let i = i + 1
        endwhile
        let s .= '%T%#TabLineFill#%='
        return s
    endfunction
endif
