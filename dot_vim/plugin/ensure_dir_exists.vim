function! EnsureDirExists ()
  let required_dir = expand("%:h")
  if !isdirectory(required_dir)
    call mkdir(required_dir, 'p')
  endif
endfunction

augroup AutoMkdir
  autocmd!
  autocmd BufWritePre * :call EnsureDirExists()
augroup END
