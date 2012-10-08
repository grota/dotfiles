if exists("+relativenumber")
  "set relativenumber " show relative line numbers
  set numberwidth=3 " narrow number column
" cycles between relative / absolute / no numbering
  function! RelativeNumberToggle()
    if (&relativenumber == 1)
      set number number?
    elseif (&number == 1)
      set nonumber number?
    else
      set relativenumber relativenumber?
    endif
  endfunc
  nnoremap <silent> <leader>n :call RelativeNumberToggle()<CR>
else " fallback
  "set number " show line numbers
" inverts numbering
  nnoremap <silent> <leader>n :set number! number?<CR>
endif
