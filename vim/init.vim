" ---------------------------------------------------------------------------- "
" Plug                                                                         "
" ---------------------------------------------------------------------------- "

" install vim-plug if not installed
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd vimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.local/share/nvim/plugged')

" utils
Plug 'scrooloose/nerdcommenter'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --bin' }
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'mhinz/vim-signify'
Plug 'dense-analysis/ale'
Plug 'SirVer/ultisnips'

" language support
Plug 'autozimu/LanguageClient-neovim', {
      \ 'branch': 'next',
      \ 'do': 'bash install.sh',
      \ }
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'Shougo/echodoc'
Plug 'ncm2/float-preview'

Plug 'godlygeek/tabular', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', {'depends': 'godlygeek/tabular', 'for': 'markdown'}
Plug 'JamshedVesuna/vim-markdown-preview', { 'for': 'markdown' }
Plug 'lervag/vim-latex', { 'for': 'tex' }
Plug 'bassstring/apple-swift' , { 'for': ['swift', 'sil', 'swiftgyb'] }

" style
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'luochen1990/rainbow'
Plug 'joshdick/onedark.vim'

call plug#end()

" ---------------------------------------------------------------------------- "
" General Settings                                                             "
" ---------------------------------------------------------------------------- "

if has("autocmd")
  filetype plugin indent on " turn on filetype plugins
endif
set title                   " show file in title bar
set history=200             " 200 lines command history
set binary                  " Enable binary support
set nowrap                  " Don't wrap long lines
set scrolloff=3             " Keep at least 3 lines above/below
set noshowmode              " Don't show current mode
set showmatch               " Show matching bracket/parenthesis/etc
set matchtime=2
set noruler
set lazyredraw              " redraw only when needed(not in execution of macro)
set synmaxcol=2500          " Limit syntax highlighting (this
                            " avoids the very slow redrawing
                            " when files contain long lines)
set updatetime=300
set shortmess+=c
set signcolumn=yes          " always draw sign column
set cmdheight=2
set hidden

if has("clipboard")
  set clipboard=unnamed     " copy to the system clipboard
  if has("unnamedplus")     " X11 support
    set clipboard+=unnamedplus
  endif
endif

set splitright              " Vertical split right
set nojoinspaces            " Use one space after punctuation

if has('mouse')
  set mouse=a
  set mousehide             " Hide mouse when typing
endif

" indentation
set copyindent              " Copy indent structure when autoindenting
set smartindent
set backspace=2             " make vim behave like any other editors
set cindent                 " Enables automatic C program indenting

set shiftwidth=2            " Preview tabs as 2 spaces
set shiftround              " Round indent to multiple of 'shiftwidth'
set tabstop=2               " Tabs are 2 spaces
set softtabstop=2           " Columns a tab inserts in insert mode
set expandtab               " Tabs are spaces

" search
set ignorecase              " Search case insensitive...
set smartcase               " but change if searched with upper case

let g:python3_host_prog = '/usr/local/bin/python3'
set pyx=3

" syntax and style
if has('nvim') || has('termguicolors')
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  set termguicolors
endif

try
  colorscheme onedark
catch
endtry

if !exists("syntax_on")
    syntax enable
endif

set number relativenumber
augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup END

augroup columntoggle
  autocmd BufEnter,FocusGained,InsertLeave * set cc=
  autocmd BufLeave,FocusLost,InsertEnter   * set cc=81
augroup END

" Persistent undo
set undofile

set noswapfile
set nobackup
set nowritebackup

" Treat given characters as a word boundary
set iskeyword-=.
set iskeyword-=#

let mapleader=","

" Return to last edit position when opening files
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") && &filetype != "gitcommit" |
  \   exe "normal! g`\"" |
  \ endif

if has("mac")
  set dictionary=/usr/share/dict/words
endif

augroup buf_write
  au!
  autocmd BufWritePre * :call StripTrailingWhitespaces()
  autocmd BufWritePost init.vim source % | :AirlineRefresh
augroup END

"Incrementing and decrementing alphabetical characters
set nrformats+=alpha
