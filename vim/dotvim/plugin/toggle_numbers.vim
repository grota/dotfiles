function! RelativeNumberToggle()
  set number!
  set relativenumber!
endfunc
nnoremap <silent> <leader>n :call RelativeNumberToggle()<CR>
set numberwidth=3 " narrow number column
