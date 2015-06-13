" Also see git://github.com/airblade/vim-rooter.git to find and cd
" to the root of a darcs, hg, bzr, svn repo
" Running Glcd before the autocommands set by netrw breaks them
" (silently!)... welcome to vim.
augroup fugitive_cd_to_repo_root
    autocmd!
    autocmd BufEnter *
                \ if exists('b:git_dir') && exists(':Glcd') |
                \ Glcd |
                \ endif
augroup END
