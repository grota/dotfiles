function! s:ToggleSpace()
    if !exists("s:space_mapped")
      let s:space_mapped = 0
    endif

    if s:space_mapped == 0
      inoremap <buffer> <Space> _
      let s:space_mapped = 1
      echo "Space MAPPED"
    else
      iunmap <buffer> <Space>
      let s:space_mapped = 0
      echo "Space UNMAPPED"
    endif
endfunction
nnoremap <leader>sm :call <SID>ToggleSpace()<CR>
