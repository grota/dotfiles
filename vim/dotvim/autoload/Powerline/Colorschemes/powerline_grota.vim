" 'N' is the non current window
" add to autoload/Powerline/Segments.vim
"\ Pl#Segment#Create('grotaspacer'  , '%{"------------------"}', Pl#Segment#NoPadding(), Pl#Segment#Modes('!n')),
" add to autoload/Powerline/Themes/default.vim "\ , 'grotaspacer'
"\ Pl#Hi#Segments(['grotaspacer'], {
"\ 'n': ['white', 'darkred'],
"\ 'N': ['black', 'darkestgreen'],
"\ }),
"\
" Here we hide the components of 'N' using colors, another soloution is to
" override autoload/Powerline/Segments.vim adding Pl#Segment#Modes('!N')
call Pl#Hi#Allocate({
	\ 'black'          : 16,
	\ 'white'          : 231,
	\
	\ 'darkestgreen'   : 22,
	\ 'darkgreen'      : 28,
	\ 'green34'        : 34,
	\ 'mediumgreen'    : 70,
	\ 'brightgreen'    : 148,
	\
	\ 'darkestcyan'    : 23,
	\ 'mediumcyan'     : 117,
	\
	\ 'darkestblue'    : 17,
	\ 'darkblue'       : 20,
	\
	\ 'lightpurple'     : 59,
	\ 'darkestred'     : 52,
	\ 'darkred'        : 88,
	\ 'mediumred'      : 124,
	\ 'brightred'      : 160,
	\ 'brightestred'   : 196,
	\
	\ 'darkestpurple'  : 55,
	\ 'mediumpurple'   : 98,
	\ 'brightpurple'   : 189,
	\
	\ 'brightorange'   : 208,
	\ 'brightestorange': 214,
	\
	\ 'almostblack'    : 232,
	\ 'gray0'          : 233,
	\ 'gray1'          : 235,
	\ 'gray2'          : 236,
	\ 'gray3'          : 239,
	\ 'gray4'          : 240,
	\ 'gray5'          : 241,
	\ 'gray6'          : 244,
	\ 'gray7'          : 245,
	\ 'gray8'          : 247,
	\ 'gray9'          : 250,
	\ 'gray10'         : 252,
	\ })

let g:Powerline#Colorschemes#powerline_grota#colorscheme = Pl#Colorscheme#Init([
	\ Pl#Hi#Segments(['SPLIT'], {
		\ 'n': ['white', 'gray1'],
		\ 'N': ['white', 'gray4'],
		\ 'i': ['white', 'darkestblue'],
		\ }),
	\
	\ Pl#Hi#Segments(['mode_indicator'], {
		\ 'n': ['darkestgreen', 'brightgreen', ['bold']],
		\ 'i': ['darkestcyan', 'white', ['bold']],
		\ 'v': ['darkred', 'brightorange', ['bold']],
		\ 'r': ['white', 'brightred', ['bold']],
		\ 's': ['white', 'gray5', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['branch', 'scrollpercent', 'raw', 'filesize'], {
		\ 'n': ['gray9', 'darkgreen'],
		\ 'N': ['gray4', 'gray4'],
		\ 'i': ['mediumcyan', 'darkblue'],
		\ }),
	\
	\ Pl#Hi#Segments(['fileinfo', 'filename'], {
		\ 'n': ['white', 'darkestgreen', ['bold']],
		\ 'N': ['gray8', 'gray4', ['bold']],
		\ 'i': ['white', 'darkblue', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['fileinfo.filepath'], {
		\ 'n': ['gray10'],
		\ 'N': ['gray6'],
		\ 'i': ['mediumcyan'],
		\ }),
	\
	\ Pl#Hi#Segments(['static_str'], {
		\ 'n': ['white', 'gray4'],
		\ 'N': ['gray7', 'gray1'],
		\ 'i': ['white', 'darkblue'],
		\ }),
	\
	\ Pl#Hi#Segments(['fileinfo.flags'], {
		\ 'n': ['brightestred', ['bold']],
		\ 'N': ['darkred'],
		\ 'i': ['brightestred', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['fileformat', 'fileencoding', 'pwd', 'filetype', 'rvm:string', 'rvm:statusline', 'virtualenv:statusline', 'charcode', 'currhigroup'], {
		\ 'n': ['gray8', 'darkestgreen'],
		\ 'i': ['mediumcyan', 'darkestblue'],
		\ }),
	\
	\ Pl#Hi#Segments(['currenttag', 'fullcurrenttag' ], {
		\ 'n': ['gray8', 'gray2'],
		\ 'i': ['mediumcyan', 'darkestblue'],
		\ }),
	\
	\ Pl#Hi#Segments(['lineinfo'], {
		\ 'n': ['gray2', 'green34', ['bold']],
		\ 'N': ['gray4', 'gray4', ['bold']],
		\ 'i': ['darkestcyan', 'mediumcyan', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['errors'], {
		\ 'n': ['brightestorange', 'gray2', ['bold']],
		\ 'i': ['brightestorange', 'darkestblue', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['lineinfo.line.tot'], {
		\ 'n': ['gray2'],
		\ 'N': ['gray4'],
		\ 'i': ['darkestcyan'],
		\ }),
	\
	\ Pl#Hi#Segments(['paste_indicator', 'ws_marker'], {
		\ 'n': ['white', 'brightred', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['gundo:static_str.name', 'command_t:static_str.name'], {
		\ 'n': ['white', 'mediumred', ['bold']],
		\ 'N': ['brightred', 'darkestred', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['gundo:static_str.buffer', 'command_t:raw.line'], {
		\ 'n': ['white', 'darkred'],
		\ 'N': ['brightred', 'darkestred'],
		\ }),
	\
	\ Pl#Hi#Segments(['gundo:SPLIT', 'command_t:SPLIT'], {
		\ 'n': ['white', 'darkred'],
		\ 'N': ['white', 'darkestred'],
		\ }),
	\
	\ Pl#Hi#Segments(['lustyexplorer:static_str.name', 'minibufexplorer:static_str.name', 'nerdtree:raw.name', 'tagbar:static_str.name'], {
		\ 'n': ['white', 'mediumgreen', ['bold']],
		\ 'N': ['mediumgreen', 'darkestgreen', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['lustyexplorer:static_str.buffer', 'tagbar:static_str.buffer'], {
		\ 'n': ['brightgreen', 'darkgreen'],
		\ 'N': ['mediumgreen', 'darkestgreen'],
		\ }),
	\
	\ Pl#Hi#Segments(['lustyexplorer:SPLIT', 'minibufexplorer:SPLIT', 'nerdtree:SPLIT', 'tagbar:SPLIT'], {
		\ 'n': ['white', 'darkgreen'],
		\ 'N': ['white', 'darkestgreen'],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:focus', 'ctrlp:byfname'], {
		\ 'n': ['brightpurple', 'darkestpurple'],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:prev', 'ctrlp:next', 'ctrlp:pwd'], {
		\ 'n': ['white', 'mediumpurple'],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:item'], {
		\ 'n': ['darkestpurple', 'white', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:marked'], {
		\ 'n': ['brightestred', 'darkestpurple', ['bold']],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:count'], {
		\ 'n': ['darkestpurple', 'white'],
		\ }),
	\
	\ Pl#Hi#Segments(['ctrlp:SPLIT'], {
		\ 'n': ['white', 'darkestpurple'],
		\ }),
	\ ])
