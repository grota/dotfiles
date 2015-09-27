" Other possibilities include https://github.com/mileszs/ack.vim.git
" and https://github.com/mhinz/vim-grepper.git
nnoremap <leader>ga :call <SID>SearchWithAG('ag --vimgrep -U', '%f:%l:%c:%m')<CR>

let s:loc_or_qf="loc"
function s:SearchWithAG(grepprg, grepformat)

  " Save existing settings.
  let l:grepprg_bak    = &l:grepprg
  let l:grepformat_bak = &grepformat

  try
    let &l:grepprg  = a:grepprg
    let &grepformat = a:grepformat

    let l:input = s:prompt(expand("<cword>"), &l:grepprg)
    if (!empty(l:input))
      let l:string_cmd = ((s:loc_or_qf ==# 'loc') ? 'l' : '') . "grep! " . l:input
      execute l:string_cmd
      execute 'botright' ((s:loc_or_qf ==# 'loc') ? 'lopen' : 'copen')
      let size = len((s:loc_or_qf ==# 'loc') ? getloclist(0) : getqflist())
      if size == 0
        execute ((s:loc_or_qf ==# 'loc') ? 'lclose' : 'cclose')
      endif
      redraw!
      echom printf('Found %d matches.', size)
    endif
  finally
    let &l:grepprg  = l:grepprg_bak
    let &grepformat = l:grepformat_bak
  endtry

endfunction

function! s:prompt(query, prefix)
  cnoremap <C-b> $$$mAgIc###<cr>
  echohl Question
  call inputsave()

  try
    let query = input('('.s:loc_or_qf.') '.a:prefix . '> ', a:query)
  finally
    cunmap <C-b>
    call inputrestore()
    echohl NONE
  endtry

  if query =~# '\V$$$mAgIc###\$'
    let s:loc_or_qf = (s:loc_or_qf ==# 'loc') ? 'qf' : 'loc'
    call histdel('input')
    return s:prompt(query[:-12], a:prefix)
  endif
  return query
endfunction
