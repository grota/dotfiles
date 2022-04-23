" grota color scheme
" vim: tw=0 ts=4 sw=4
" Not a real complete colorscheme it only tries
" to fix the colors defined in the default colorscheme

" highlight clear
set background=dark
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "grota"

highlight Special ctermfg=224 guifg=#ffd7d7
highlight Visual term=reverse ctermbg=236 guibg=DarkGrey
highlight FoldColumn term=standout ctermfg=14 ctermbg=233 guifg=Cyan guibg=Grey7
highlight SignColumn term=standout ctermfg=14 ctermbg=232 guifg=Cyan guibg=Grey3
highlight CursorLine term=underline guibg=gray9 ctermbg=234 cterm=NONE
highlight LineNr guifg=GreenYellow
highlight Statement guifg=#ffff00 gui=none
highlight String term=underline ctermfg=173 guifg=#d7875f
highlight Comment term=bold cterm=bold ctermfg=242 guifg=#6c6c6c
highlight Normal guifg=DarkSeaGreen1 ctermfg=157 ctermbg=none
highlight Constant ctermfg=13
highlight Type cterm=bold ctermfg=83
highlight PreProc ctermfg=176 guifg=#d787d7
highlight MatchParen cterm=bold ctermbg=19 guibg=DarkCyan
highlight Directory ctermfg=130 guifg=#af5f00
highlight Pmenu ctermbg=8 guibg=SpringGreen4 guifg=gray15
highlight PmenuSel ctermbg=247 ctermfg=233 guibg=green1 guifg=black
highlight Search term=reverse ctermfg=0 ctermbg=3 guifg=black guibg=gold
highlight Folded term=standout ctermfg=14 ctermbg=234 guifg=#00ffff guibg=#1c1c1c
highlight StatusLineNC ctermbg=240 cterm=none term=none gui=none
highlight DiffChange ctermbg=53
highlight DiffText ctermbg=235
highlight DiffAdd ctermbg=22
highlight DiffDelete ctermbg=52
highlight Question ctermfg=123
highlight TabLineFill ctermfg=234 guibg=#121212
highlight TabLine ctermbg=234 ctermfg=240 cterm=NONE
highlight TabLineSel ctermfg=250 ctermbg=236 cterm=NONE
highlight QuickfixLine guibg=#222222
" custom highlight group
highlight TabLineModifiedMark ctermfg=1 ctermbg=22 cterm=bold
highlight TabLineNotModifiableMark ctermfg=240 ctermbg=234 cterm=bold
highlight VertSplit ctermfg=240
if has('nvim')
    highlight WinSeparator guibg=none
endif
highlight TagbarHighlight term=reverse ctermfg=0 ctermbg=57 guifg=black guibg=blue
" Default Highlights {{{
highlight def InterestingWord1 guifg=#000000 ctermfg=16 guibg=#ffa724 ctermbg=214
highlight def InterestingWord2 guifg=#000000 ctermfg=16 guibg=#aeee00 ctermbg=154
highlight def InterestingWord3 guifg=#000000 ctermfg=16 guibg=#8cffba ctermbg=121
highlight def InterestingWord4 guifg=#000000 ctermfg=16 guibg=#b88853 ctermbg=137
highlight def InterestingWord5 guifg=#000000 ctermfg=16 guibg=#ff9eb8 ctermbg=211
highlight def InterestingWord6 guifg=#000000 ctermfg=16 guibg=#ff2c4b ctermbg=195
" }}}
" See after/plugin/after_actions.vim for some other airline colors.
