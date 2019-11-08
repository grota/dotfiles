set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/dotfiles/vim/dotvim/vimrc
" deoplete {{{
let g:deoplete#enable_at_startup = 1
"call deoplete#custom#option('profile', v:true)
"call deoplete#enable_logging('DEBUG', 'deoplete.log')
"call deoplete#custom#source('_', 'is_debug_enabled', 1)
"call deoplete#custom#option('sources', {
      "\ 'php': ['omni'],
      "\})
"call deoplete#custom#source('omni', 'functions', {
      "\ 'php':  'phpcomplete#CompletePHP',
      "\})
"call deoplete#custom#var('omni', 'input_patterns', {
      "\ 'php': '\w+|[^. \t]->\w*|\w+::\w*',
      "\})
"let g:deoplete#ignore_sources = get(g:, 'deoplete#ignore_sources', {})
"let g:deoplete#ignore_sources.php = ['omni']
"call deoplete#custom#option('sources', {
      "\ 'php': ['phpcd'],
      "\})

" }}}
