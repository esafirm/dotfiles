syntax on
set number
set clipboard=unnamed
let python_highlight_all=1
set laststatus=2
let g:airline_powerline_fonts=1

" Split Pane Pro Tips
set splitright
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Map leader key to Space
let mapleader=" "

set nocompatible              " required
filetype off                  " required

set noshowmode

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" --- PLUGIN ----

" Specify a directory for plugins
" - For Neovim: stdpath('data') . '/plugged'
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Easy motion like AceJump on emacs
Plug 'easymotion/vim-easymotion'

" Vim Airline (Powerline)
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" File Tree
Plug 'preservim/nerdtree'
let NERDTreeIgnore=['\.pyc$', '\~$'] "ignore files in NERDTree

" Python Specific
Plug 'vim-scripts/indentpython.vim' " Python Indentation
set encoding=utf-8 " set encoding

" Async linting/fixing (replaces syntastic + vim-flake8)
Plug 'dense-analysis/ale'

" Catppuccin theme
Plug 'catppuccin/vim', { 'as': 'catppuccin', 'branch': 'main' }

" Initialize plugin system
call plug#end()

" Restore filetype detection (must come after plug#end)
filetype plugin indent on

" --- Search ---
set incsearch
set hlsearch
set ignorecase
set smartcase

" --- Undo ---
set undofile
set undodir=~/.vim/undo//

" --- UI ---
set relativenumber
set wildmenu
set wildmode=longest:full,full

" Theme
set termguicolors
colorscheme catppuccin_mocha
let g:airline_theme = 'catppuccin_mocha'