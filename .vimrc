"" vim configure file for @umisama

""===============================================
"" BASICS
""===============================================
" Compatible mode => OFF
set nocompatible

" Syntax Highlight and filetype detect.
filetype plugin on
syntax on

" Command view
set hidden
set wildmenu
set showcmd

" Editing
set autoindent
set nostartofline
set ruler
set laststatus=2

" Visual
set visualbell
set t_vb=
set mouse=a
set number

" Tab
set shiftwidth=4
set tabstop=4

" word finding
set hlsearch
set ignorecase
set smartcase
set incsearch

" colorscheme
set t_Co=256
colorscheme desert

""===============================================
"" VISUAL
""===============================================

"  Underline
setlocal cursorline
autocmd WinEnter * setlocal cursorline
autocmd WinLeave * setlocal nocursorline

" status line
set statusline=\ [%n]
set statusline+=\ %F
set statusline+=\ %7(%m\ %r%) 
set statusline+=%=\ \ \ (%l,%c)

" tab
set guioptions-=e			"for windows gvim( always use text-base tabline )
set showtabline=2

" menu
set guioptions-=m
set guioptions-=T

""===============================================
"" SWAP AND ~ FILE
""===============================================

set backup
if has('win32')
set backupdir=C:\\vim\\backups
else
	set backupdir=~/.vim_backup
endif

set swapfile
if has('win32')
set directory=C:\\vim\\swaps
else
	set directory=~/.vim_swap
endif


""===============================================
"" KEY MAPPING
""===============================================
" GUI-Style Copy and Paste
vnoremap <C-c> "+y
nnoremap <C-v> "+p
inoremap <C-v> "+p
vnoremap <C-v> x"+p

" improve Command-mode
cnoremap <C-v> <C-r>+

" tabmove
nnoremap t gt
nnoremap T gT
nnoremap <C-Tab> gt
nnoremap <C-S-Tab> gT

" into brackets(input mode)
inoremap {} {}<LEFT>
inoremap [] []<LEFT>
inoremap () ()<LEFT>
inoremap "" ""<LEFT>
inoremap '' ''<LEFT>
inoremap <> <><LEFT>

" cursor on input mode(input mode)
inoremap <C-h> <LEFT>
inoremap <C-j> <DOWN>
inoremap <C-k> <UP>
inoremap <C-l> <RIGHT>

" instant searching
nnoremap <C-1> *
nnoremap <C-2> g#
nnoremap <C-3> #
nnoremap <C-4> g#

" cursor memory shortcut
nnoremap <F1> `a
nnoremap <F2> `b
nnoremap <F3> `c
nnoremap <F4> `d
nnoremap <C-F1> ma
nnoremap <C-F2> mb
nnoremap <C-F3> mc
nnoremap <C-F4> md

""===============================================
"" GOLANG
""===============================================
filetype off
filetype plugin indent off
set runtimepath+=$GOROOT/misc/vim
filetype plugin indent on
syntax on

""===============================================
"" USER COMMAND
""===============================================

" Load commands
if has('win32')
	execute 'source ~/_vimrc.command'
	try
		execute 'source ~/_vimrc.office'
	endtry
else
	execute 'source ~/.vimrc.command'
	try
		execute 'source ~/.vimrc.office'
	endtry
end

