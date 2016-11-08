syntax on
set number
let python_highlight_all=1
set laststatus=2
let g:airline_powerline_fonts=1
let g:airline_theme='solarized'

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

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" Add all your plugins here (note older versions of Vundle used Bundle instead of Plugin)

" Easy motion like AceJump on emacs
Plugin 'easymotion/vim-easymotion'

" Vim Airline (Powerline)
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'

" Search
Plugin 'kien/ctrlp.vim'

" File Tree
Plugin 'scrooloose/nerdtree'
let NERDTreeIgnore=['\.pyc$', '\~$'] "ignore files in NERDTree

" Python Specific 
Plugin 'vim-scripts/indentpython.vim' " Python Indentation
set encoding=utf-8 " set encoding

let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

Plugin 'scrooloose/syntastic' " syntax higlight
Plugin 'nvie/vim-flake8' " PEP8 idk what that is


" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

set noshowmode
