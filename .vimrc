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
set nostartofline
set ruler
set laststatus=2

" Visual
set visualbell
set t_vb=
set mouse=a
if !has("nvim")
	set ttymouse=xterm2
endif
set number
set completeopt-=preview

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
colorscheme elflord

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

" vim-quickhl(minimal)
nmap <Space>m <Plug>(quickhl-manual-this)
xmap <Space>m <Plug>(quickhl-manual-this)
nmap <Space>M <Plug>(quickhl-manual-reset)
xmap <Space>M <Plug>(quickhl-manual-reset)

""===============================================
"" NEO BUNDLE 
""===============================================
set runtimepath+=$HOME/.vim/bundle/neobundle.vim
call neobundle#begin(expand('~/.vim/bundle/'))
NeoBundleFetch 'Shugo/neobundle.vim'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 't9md/vim-quickhl'
NeoBundle 'othree/html5.vim'
NeoBundle 'hail2u/vim-css3-syntax'
NeoBundle 'pangloss/vim-javascript'
NeoBundle 'leafgarland/typescript-vim'
NeoBundle 'fatih/vim-go'
NeoBundle 'Shougo/vimproc.vim', {
\ 'build' : {
\     'windows' : 'tools\\update-dll-mingw',
\     'cygwin' : 'make -f make_cygwin.mak',
\     'mac' : 'make -f make_mac.mak',
\     'linux' : 'make',
\     'unix' : 'gmake',
\    },
\ }
NeoBundle 'scrooloose/syntastic'
NeoBundle 'Shougo/neocomplcache.vim'
NeoBundle 'jason0x43/vim-js-indent'
NeoBundle 'Shougo/neocomplcache'
NeoBundle 'Quramy/tsuquyomi'
NeoBundle 'jason0x43/vim-js-indent'
call neobundle#end()
filetype plugin indent on
NeoBundleCheck

""===============================================
"" NeoComplCache
""===============================================
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

" Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
\	'default' : ''
\	}

" Plugin key-mappings.
inoremap <expr><C-g>     	neocomplcache#undo_completion()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return neocomplcache#smart_close_popup() . "\<CR>"
endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <BS>: close popup and delete backword char.
inoremap <expr><BS>	  neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><C-y>  neocomplcache#close_popup()
inoremap <expr><C-e>  neocomplcache#cancel_popup()

""===============================================
"" golang
""===============================================
if !exists('g:neocomplcache_omni_patterns')
    let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.go = '[^.[:digit:] *\t]\.\w*'

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
