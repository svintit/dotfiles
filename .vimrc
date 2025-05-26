set nocompatible
filetype off


set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'Raimondi/delimitMate'
Plugin 'mhinz/vim-startify' 
Plugin 'vim-scripts/indentpython.vim'
Plugin 'luochen1990/rainbow'
Plugin 'drewtempelmeyer/palenight.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'Yggdroot/indentLine'  
Plugin 'scrooloose/nerdtree'
Plugin 'kaicataldo/material.vim'
Plugin 'nvie/vim-flake8'
Plugin 'hzchirs/vim-material'
Plugin 'wikitopian/hardmode'
call vundle#end()

filetype plugin indent on

nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode

set ttimeoutlen=50

set so=999

vnoremap <C-c> "*y"
"set clipboard=unnamedplus
map <q> <Nop>

syntax on
set number
filetype plugin indent on
set noshowmode
set conceallevel=1
let g:one_allow_italics = 1
set encoding=utf-8
set nowrap
set completeopt-=preview
set term=screen-256color
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

" ------ NERDTree ------
let g:WebDevIconsNerdTreeAfterGlyphPadding = '  '

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

let NERDTreeQuitOnOpen=1
let NERDTreeShowHidden=1
let g:material_theme_style='palenight-community'
nmap t :NERDTreeToggle<CR>
nmap <silent> T :NERDTreeFind<cr>

let NERDTreeIgnore = ['\.pyc$', '\.class$']

no <down> ddp
no <left> :bp<cr>
no <right> :bn<cr>
no <up> ddkP

noremap <S-w> :w<cr>
nnoremap <S-q> :q<cr>

let g:indentLine_conceallevel=0

imap jj <Esc>

set laststatus=2

set t_Co=256

let g:material_style='darker-community'
set background=dark
colorscheme material

set termguicolors
let g:rainbow_active = 1

let g:rainbow_conf = {
	\	'guifgs': ['cyan', 'yellow', 'orange', 'firebrick'],
	\	'ctermfgs': ['lightblue', 'lightyellow', 'lightcyan', 'lightmagenta'],
	\	'operators': '_,_',
	\	'parentheses': ['start=/(/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/{/ end=/}/ fold'],
	\	'separately': {
	\		'*': {},
	\		'tex': {
	\			'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/'],
	\		},
	\		'lisp': {
	\			'guifgs': ['royalblue3', 'darkorange3', 'seagreen3', 'firebrick', 'darkorchid3'],
	\		},
	\		'vim': {
	\			'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/', 'start=/{/ end=/}/ fold', 'start=/(/ end=/)/ containedin=vimFuncBody', 'start=/\[/ end=/\]/ containedin=vimFuncBody', 'start=/{/ end=/}/ fold containedin=vimFuncBody'],
	\		},
	\		'html': {
	\			'parentheses': ['start=/\v\<((area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)[ >])@!\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'|[^ '."'".'"><=`]*))?)*\>/ end=#</\z1># fold'],
	\		},
	\		'css': 0,
	\	}
	\}

set cursorline
hi CursorLine term=bold cterm=bold guibg=Grey12

if &term =~# '^screen'
	    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
	    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif

set t_ut=
