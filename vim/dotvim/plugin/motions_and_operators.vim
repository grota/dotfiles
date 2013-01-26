" copied, once again, from https://github.com/sjl
onoremap an :<c-u>call <SID>NextTextObject('a', 'f')<cr>
xnoremap an :<c-u>call <SID>NextTextObject('a', 'f')<cr>
onoremap in :<c-u>call <SID>NextTextObject('i', 'f')<cr>
xnoremap in :<c-u>call <SID>NextTextObject('i', 'f')<cr>

onoremap al :<c-u>call <SID>NextTextObject('a', 'F')<cr>
xnoremap al :<c-u>call <SID>NextTextObject('a', 'F')<cr>
onoremap il :<c-u>call <SID>NextTextObject('i', 'F')<cr>
xnoremap il :<c-u>call <SID>NextTextObject('i', 'F')<cr>

function! s:NextTextObject(motion, dir)
  let c = nr2char(getchar())

  if c ==# "b"
      let c = "("
  elseif c ==# "B"
      let c = "{"
  elseif c ==# "r"
      let c = "["
  endif

  exe "normal! ".a:dir.c."v".a:motion.c
endfunction

" partially copied from https://github.com/goldfeld/vim-seek
function! Seek(plus)
  let c1 = getchar()
  let c2 = getchar()
  let line = getline('.')
  let pos = getpos('.')[2]
  let seek = stridx(l:line[l:pos :], nr2char(l:c1).nr2char(l:c2))
  if l:seek != -1
    execute 'normal! 0'.(l:pos + l:seek + a:plus).'l'
  endif
endfunction

function! SeekBack(plus)
  let c1 = getchar()
  let c2 = getchar()
  let line = getline('.')
  let pos = getpos('.')[2]
  let seek = strridx(l:line[: l:pos - 1], nr2char(l:c1).nr2char(l:c2))
  if l:seek != -1
    execute 'normal! 0'.(l:seek + a:plus).'l'
  endif
endfunction
nnoremap <silent> s :<C-U>call Seek(0)<CR>
nnoremap <silent> S :<C-U>call SeekBack(0)<CR>
