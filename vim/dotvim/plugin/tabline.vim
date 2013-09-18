if exists("+showtabline")
    function! GrotaTabLine()
        let toreturn = ''
        let number_of_windows_in_tab = ''
        let currenttab = tabpagenr()
        let i = 1
        while i <= tabpagenr('$')
            let buflist = tabpagebuflist(i)
            let winnr = tabpagewinnr(i)
            let toreturn .= '%' . i . 'T'
            let number_of_windows_in_tab = tabpagewinnr(i,'$')
            let toreturn .= (i == currenttab ? '%#TabLineSel#' : '%#TabLine#')
            let toreturn .= '['
            let bufnr = buflist[winnr - 1]
            let file = bufname(bufnr)
            let buftype = getbufvar(bufnr, 'buftype')
            if buftype == 'nofile'
                if file =~ '\/.'
                    let file = substitute(file, '.*\/\ze.', '', '')
                endif
            elseif &l:buftype == 'quickfix'
              let file = 'QF '
            else
                let file = fnamemodify(file, ':p:t')
            endif
            if file == ''
                let file = '______'
            endif
            let toreturn .= file
            let toreturn .= (&modified ? ' ' : '')
            if (&modifiable)
              let modified_flag_highlight = 'TabLineModifiedMark'
            else
              let modified_flag_highlight = 'TabLineNotModifiableMark'
            endif
            let toreturn .= (i == currenttab ? '%#'.modified_flag_highlight.'#%m%#TabLineSel#' : '')
            let toreturn .= ']'
            let toreturn .= '%#TabLineFill# '
            let i = i + 1
        endwhile
        let toreturn .= '%T%#TabLineFill#%='
        return toreturn
    endfunction
endif
