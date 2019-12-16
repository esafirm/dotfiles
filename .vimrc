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
Plug 'scrooloose/nerdtree'
let NERDTreeIgnore=['\.pyc$', '\~$'] "ignore files in NERDTree

" Python Specific 
Plug 'vim-scripts/indentpython.vim' " Python Indentation
set encoding=utf-8 " set encoding

let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

Plug 'scrooloose/syntastic' " syntax higlight
Plug 'nvie/vim-flake8' " PEP8 idk what that is

" Initialize plugin system
call plug#end()