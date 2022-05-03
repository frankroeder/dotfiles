set nocompatible            " Don't make Vim vi-compatible.
" ---------------------------------------------------------------------------- "
" Plug                                                                         "
" ---------------------------------------------------------------------------- "
" install vim-plug if not installed
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd vimEnter * PlugInstall --sync | source $MYVIMRC
endif
call plug#begin('~/.vim/bundle')

" utils
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --no-zsh' }
Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'rstacruz/vim-closer'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'mhinz/vim-signify'

" style
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'luochen1990/rainbow'
Plug 'ayu-theme/ayu-vim'

call plug#end()

" ---------------------------------------------------------------------------- "
" General Settings                                                             "
" ---------------------------------------------------------------------------- "

filetype plugin indent on
set history=200             " Remember more commands
set autoread                " Auto reload file after external command
set wildmenu                " Visual autocomplete for command menu
set ttyfast                 " Fast terminal
set title
set ttymouse=xterm2
set binary                  " Enable binary support

set nowrap                  " Don't wrap long lines
set scrolloff=3             " Keep at least 3 lines above/below
set noshowmode              " Don't show current mode
set showmatch               " Show matching bracket/parenthesis/etc
set matchtime=2
set showcmd                 " Show incomplete command
set lazyredraw              " redraw only when needed(not in execution of macro)
set synmaxcol=2500          " Limit syntax highlighting (this
                            " avoids the very slow redrawing
                            " when files contain long lines).

 " Use the system clipboard
set clipboard=unnamed
if has("unnamedplus")
  set clipboard+=unnamedplus
endif

if has('mouse')
  set mouse=a
  set mousehide
endif

" indentation
set smarttab
set smartindent
set autoindent
set backspace=2
set cindent

set shiftwidth=2
set tabstop=2
set softtabstop=2
set expandtab

" search
set ignorecase
set smartcase
set hlsearch

" syntax and style
set background=dark
set encoding=utf-8
set laststatus=2

set termguicolors
let ayucolor="mirage"
colorscheme ayu

syntax enable

set number relativenumber
augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup END

" Persistent undo
" Create undo dir if not exists
if empty(glob('~/.vim/undo'))
  silent !mkdir ~/.vim/undo
else
  set undofile
  set undodir=$HOME/.vim/undo
endif

set noswapfile
set nobackup

" Treat given characters as a word boundary
set iskeyword-=.                " Make '.' end of word designator
set iskeyword-=#                " Make '#' end of word designator
set splitright                  " Vertical split right

let mapleader=","

" Return to last edit position when opening files
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif

" ---------------------------------------------------------------------------- "
" General Mappings                                                             "
" ---------------------------------------------------------------------------- "

" Don't yank to default register when changing something
nnoremap c "xc
xnoremap c "xc

map <C-J> :bprev<CR>
map <C-K> :bnext<CR>

" Close buffer
noremap <Leader>c :bd<CR>

" Clear search highlight
nnoremap <silent> <Leader><space> :noh<CR>

" Toggle wrap mode
nnoremap <Leader>wr :set wrap!<CR>

" Fast save
nnoremap <Leader><Leader> :w<CR>

" Disable Arrow keys in Escape mode
map <Up> <nop>
map <Down> <nop>
map <Left> <nop>
map <Right> <nop>

" Disable Arrow keys in Insert mode
imap <Up> <nop>
imap <Down> <nop>
imap <Left> <nop>
imap <Right> <nop>

" Rename current file
function! RenameFile()
  let old_name = expand('%')
  let new_name = input('New file name: ', expand('%'), 'file')
  if new_name != '' && new_name != old_name
    exec ':saveas ' . new_name
    exec ':silent !rm ' . old_name
    redraw!
  endif
endfunction
map <Leader>re :call RenameFile()<CR>

" [,* ] Search and replace the word under the cursor.
" current line
nmap <Leader>* :s/\<<C-r><C-w>\>//g<Left><Left>
" all occurrences
nmap <Leader>** :%s/\<<C-r><C-w>\>//g<Left><Left>

" w!! to save with sudo
cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!

" replace word with text in register "0
nnoremap <Leader>pr viw"0p

" Switch CWD to the directory of the open buffer
map <Leader>cd :cd %:p:h<CR>:pwd<CR>

" Close quickfix window (,qq)
map <Leader>qq :cclose<CR>

" List contents of all registers
nnoremap <silent> "" :registers<CR>

" add semicolon at end of line
map <Leader>; g_a;<Esc>

" tmux style shortcuts
nnoremap <C-W>% :split<CR>
nnoremap <C-W>" :vsplit<CR>

" remain in visual mode after code shift
vnoremap < <gv
vnoremap > >gv

" ---------------------------------------------------------------------------- "
" Plugin Configuration                                                         "
" ---------------------------------------------------------------------------- "

" Rainbow
let g:rainbow_active = 1

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme='ayu_mirage'

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_tabs= 1
let g:arline#extensions#virtualenv#enabled = 1
let g:airline#extensions#whitespace#enabled = 0

" NERDComment
let g:NERDSpaceDelims = 1
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'
let g:NERDCustomDelimiters = { 'c': { 'left': '/**','right': '*/' } }
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

nnoremap <Leader>cc NERDComComment
nnoremap <Leader>c<space> NERDComToggleComment
nnoremap <Leader>cs NERDComSexyComment

" FZF
let g:fzf_command_prefix = 'Fzf'
let g:fzf_layout = { 'up': '~40%' }
let g:fzf_action = {
      \ 'ctrl-x': 'split',
      \ 'ctrl-v': 'vsplit' }
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }
let g:fzf_history_dir = '~/.local/share/fzf-history'
" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1
noremap <C-T> :FZF --reverse --inline-info --cycle<CR>
noremap <C-H> :FzfHelptags <CR>
nnoremap <C-P> :FzfBLines<Cr>
" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
nnoremap <Leader>gc :FzfBCommits<Cr>
nnoremap <Leader>h :FzfHistory<Cr>
imap <C-X><C-F> <plug>(fzf-complete-path)
imap <C-X><C-J> <plug>(fzf-complete-file-ag)
imap <C-X><C-L> <plug>(fzf-complete-line)
