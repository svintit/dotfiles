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
Plugin 'nvie/vim-flake8'
Plugin 'dracula/vim'
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

imap <C-j> <ESC>ji
imap <C-h> <ESC>hi
imap <C-k> <ESC>ki
imap <C-l> <ESC>li
imap <C-L> <ESC>A
imap <C-space> <ESC>
vmap <C-space> <ESC>

set laststatus=2
let g:dracula_colorterm = 0

set t_Co=256
colorscheme dracula


set termguicolors
let g:rainbow_active = 1
let g:airline_theme='dracula'

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
