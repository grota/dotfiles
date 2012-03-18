" Define the wildignore from gitignore. Primarily for CommandT
function! s:WildignoreFromGitignore()
    let gitignore = '.gitignore'
    if filereadable(gitignore)
        let igstring = ''
        for oline in readfile(gitignore)
            let line = substitute(oline, '\s|\n|\r', '', "g")
            if line =~ '^#' | con  | endif
            if line == ''   | con  | endif
            if line =~ '^!' | con  | endif
            if line =~ '/$' | let igstring .= "," . line . "*" | con | endif
            let igstring .= "," . line
        endfor
        let execstring = "set wildignore+=".substitute(igstring,'^,','',"g")
        execute execstring
    endif
endfunction

augroup cd_to_git_root_set_wildignore_to_gitignore
    au!
    autocmd BufEnter *
                \ if exists('b:git_dir') && exists(':Gcd') |
                \ Gcd                                      |
                \ call s:WildignoreFromGitignore()
augroup END
