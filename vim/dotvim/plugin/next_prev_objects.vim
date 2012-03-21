" A Vim plugin that defines some custom text obiexts (,[,{,a
" Maintainer: Giuseppe Rota <rota.giuseppe@gmail.com>
" Shamelessly copied from David Larson <david@thesilverstream.com>
"
" Motion for "next/prev object". For example, "dni(" would go to the next "()"
" pair and delete its contents.
"     np         ia        ([{a
" next/prev inner/around
"
" vnaa  ooXooooooooo (1111,2222,3333,(aaaa,bbbb, cccc), (xxxx,yyyy,zzzz))
"                     ^^^^^
" v2naa ooXooooooooo (1111,2222,3333,(aaaa,bbbb, cccc), (xxxx,yyyy,zzzz))
"                     ^^^^^^^^^^
" vnaa  ooXooooooooo ((xxxx,yyyy,zzzz), (aaaa,bbbb,cccc),3333, 2222,1111)
"                     ^^^^^^^^^^^^^^^^^
" v2naa ooXooooooooo ((xxxx,yyyy,zzzz), (aaaa,bbbb,cccc),3333, 2222,1111)
"                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
"       testfunction (1111,2222,3333,(aaaa,bbbb, cccc), (xxxx,yyyy,zzzz)) vpaa  ooXooooooooooo
"                                                     ^^^^^^^^^^^^^^^^^^
"       testfunction (1111,2222,3333,(aaaa,bbbb, cccc), (xxxx,yyyy,zzzz)) v2paa ooXooooooooooo
"                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
"       testfunction ((xxxx,yyyy,zzzz), (aaaa,bbbb,cccc),3333, 2222,1111) vpaa  ooXooooooooooo
"                                                                  ^^^^^
"       testfunction ((xxxx,yyyy,zzzz), (aaaa,bbbb,cccc),3333, 2222,1111) v2paa ooXooooooooooo
"                                                            ^^^^^^^^^^^

onoremap na :<c-u>call <SID>NextPrevTextObject('a', 'next')<cr>
xnoremap na :<c-u>call <SID>NextPrevTextObject('a', 'next')<cr>
onoremap ni :<c-u>call <SID>NextPrevTextObject('i', 'next')<cr>
xnoremap ni :<c-u>call <SID>NextPrevTextObject('i', 'next')<cr>
onoremap pa :<c-u>call <SID>NextPrevTextObject('a', 'prev')<cr>
xnoremap pa :<c-u>call <SID>NextPrevTextObject('a', 'prev')<cr>
onoremap pi :<c-u>call <SID>NextPrevTextObject('i', 'prev')<cr>
xnoremap pi :<c-u>call <SID>NextPrevTextObject('i', 'prev')<cr>

" missing mappings for argument object, without next/prev: aa/ia
" the other mappings for the simple objects: i( a( ib ab i[ a[
" ecc... ecc... are already provided by vim itself
xnoremap aa :<c-u>call <SID>ArgumentObject('a')<cr>
onoremap aa :<c-u>call <SID>ArgumentObject('a')<cr>
xnoremap ia :<c-u>call <SID>ArgumentObject('i')<cr>
onoremap ia :<c-u>call <SID>ArgumentObject('i')<cr>

function! s:NextPrevTextObject(around_or_inner, next_or_prev)
    let mycount = v:count1
    let ve_save = &ve
    set virtualedit=onemore
    let mark_m_save = getpos("'m")
    try
        let obj = nr2char(getchar())
        let simple_objects    = ['b','(',')']
        let simple_objects   += ['d','[',']']
        let simple_objects   += ['B','{','}']
        let argument_objects  = ['a']

        if index(simple_objects+argument_objects, obj) < 0
            return
        endif

        " search forwards or backwards
        if a:next_or_prev ==# 'next'
            let searchopt='W'
        elseif a:next_or_prev ==# 'prev'
            let searchopt='Wb'
        endif

        " argument text object
        if obj ==# 'a'
            " Move onto the first ,() char
            if search('[,()]',searchopt.'sc') <= 0
                return
            endif
            if a:next_or_prev ==# 'next'
                " next: move right and set the m mark
                normal! lmm
                " go back left if current char is (
                if getline(".")[col(".")-1] ==# '('
                    normal! h
                endif
            elseif a:next_or_prev ==# 'prev'
                " prev: move left and set the m mark
                normal! hmm
                " go back right if current char is )
                if getline(".")[col(".")-1] ==# ')'
                    normal! l
                endif
            endif
            " start visual mode
            normal! v
            " stride, haters gonna hate
            while mycount
                if searchpair('(',',',')', searchopt, "s:skip()") <= 0
                    echom 'Not enough arguments found in the text'
                    "execute "normal! `'\<esc>"
                    normal! `'
                    return
                endif
                let mycount -= 1
            endw
            " inner mode: simply go back 1 char
            if a:around_or_inner ==# 'i' || getline(".")[col(".")-1] ==# ')' || getline(".")[col(".")-1] ==# '('
                if a:next_or_prev ==# 'prev'
                    normal! l
                else
                    normal! h
                endif
            endif
            normal! o`m
            return
        endif

        " steve's text-obj
        if obj ==# "b"
            let obj = "("
        elseif obj ==# "d"
            let obj = "["
        elseif obj ==# "B"
            let obj = "{"
        endif
        " Search for the start of the parameter text object
        if search(obj, searchopt) <= 0
            return
        endif
        exe "normal! v".a:around_or_inner.obj
   finally
      let &ve = ve_save
      call setpos("'m", mark_m_save)
   endtry
endfunction

function s:ArgumentObject(mode)
   let c = v:count1
   let ve_save = &ve
   set virtualedit=onemore
   let l_save = @l
   let mark_l_save = getpos("'l")
   try
       " go right if current char is (
       if getline(".")[col(".")-1] ==# '('
           normal! l
       endif
      " Search for the start of the parameter text object
      if searchpair('(',',',')', 'bWs', "s:skip()") <= 0
         return
      endif

      normal! "lyl
      if a:mode == "a" && @l == ','
         let gotone = 1
         normal! ml
      else
         normal! lmlh
      endif

      while c
         " Search for the end of the parameter text object
         if searchpair('(',',',')', 'W', "s:skip()") <= 0
            normal! `'
            return
         endif
         normal! "lyl
         if @l == ')' && c > 1
            " found the last parameter when more is asked for, so abort
            normal! `'
            return
         endif
         let c -= 1
      endwhile

      if a:mode == "a" && @l == ',' && !exists("gotone")
      else
         normal! h
      endif
      normal! v`l
   finally
      let &ve = ve_save
      let @l = l_save
      call setpos("'l", mark_l_save)
   endtry
endfunction

function s:skip()
   let name = synIDattr(synID(line("."), col("."), 0), "name")
   if name =~? "comment"
      return 1
   elseif name =~? "string"
      return 1
   endif
   return 0
endfunction
