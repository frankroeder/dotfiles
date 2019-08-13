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
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do':
      \ './install --all --no-bash -no-zsh' }
Plug 'junegunn/fzf.vim'
Plug 'SirVer/ultisnips'
Plug 'rstacruz/vim-closer'
Plug 'tpope/vim-fugitive'
Plug 'w0rp/ale'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'mhinz/vim-signify'

" language support
Plug 'Valloric/YouCompleteMe', { 'do':
      \ './install.py --clang-completer --go-completer' }
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'plasticboy/vim-markdown', {'depends': 'godlygeek/tabular'}
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'lervag/vim-latex'

" style
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'luochen1990/rainbow'
Plug 'ap/vim-css-color'
Plug 'arcticicestudio/nord-vim'

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
if has("clipboard")
  set clipboard=unnamed     " copy to the system clipboard
  if has("unnamedplus")     " X11 support
    set clipboard+=unnamedplus
  endif
endif

set splitright              " Vertical split right
set nojoinspaces            " Use one space after punctuation
set copyindent              " Copy indent structure when autoindenting

if has('mouse')
  set mouse=a
  set mousehide             " Hide mouse when typing
endif

" indentation
set smartindent
set backspace=2             " make vim behave like any other editors
set cindent                 " Enables automatic C program indenting

set shiftwidth=2            " Preview tabs as 2 spaces
set tabstop=2               " Tabs are 2 spaces
set softtabstop=2           " Columns a tab inserts in insert mode
set expandtab               " Tabs are spaces

" search
set ignorecase              " Search case insensitive...
set smartcase               " but change if searched with upper case

" syntax and style
set t_Co=256                " Enable full-color support

if has('nvim') || has('termguicolors')
  set termguicolors
endif

try
  colorscheme nord
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

" Treat given characters as a word boundary
set iskeyword-=.
set iskeyword-=#

let mapleader=","

" Return to last edit position when opening files
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif

" Set spell in certain cases
autocmd FileType gitcommit setl spell textwidth=72

function! <SID>StripTrailingWhitespaces()
  " last cursor and search position
  let _s=@/
  let l = line(".")
  let c = col(".")
  %s/\s\+$//e
  let @/=_s
  call cursor(l, c)
endfunction

augroup buf_write
  au!
  autocmd BufWritePre * :call <SID>StripTrailingWhitespaces()
  autocmd BufWritePost init.vim source %
augroup END

" Make crontab happy
autocmd filetype crontab setlocal nobackup nowritebackup

" ---------------------------------------------------------------------------- "
" General Mappings                                                             "
" ---------------------------------------------------------------------------- "

" tab navigation
map <Tab> :bnext<CR>
map <S-Tab> :bprev<CR>

" Don't yank to default register when changing something
nnoremap c "xc
xnoremap c "xc

" Close buffer
noremap <Leader>c :bd<CR>
" Clear search highlight
nnoremap <silent> <Leader><space> :noh<CR>
" Toggle wrap mode
nnoremap <Leader>wr :set wrap!<CR>
" Fast save
nnoremap <Leader><Leader> :w<CR>

" spell check
map <silent> <F6> :setlocal spell! spelllang=en_us<CR>
map <silent> <F7> :setlocal spell! spelllang=de_de<CR>

" Spell error: pick the first result
nnoremap <Leader>z z=1<CR><CR>

" Fix spelling mistakes the fast way
inoremap <C-S> <C-G>u<Esc>[s1z=`]a<C-G>u

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

" Format JSON with jq
nnoremap <silent> <Leader>fj :%!jq '.'<CR>

" [,* ] Search and replace the word under the cursor.
nmap <Leader>* :%s/\<<C-r><C-w>\>//g<Left><Left>

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

nnoremap <C-W>- :split<CR>
nnoremap <C-W>\| :vsplit<CR>

" remain in visual mode after code shift
vnoremap < <gv
vnoremap > >gv

" ---------------------------------------------------------------------------- "
" Plugin Configuration                                                         "
" ---------------------------------------------------------------------------- "

" Rainbow
let g:rainbow_active = 1

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_update_on_bufenter=0

" TeX and Markdown
let g:tex_flavor = "latex"
let g:vimtex_view_method='skim'
let g:vimtex_quickfix_mode=0
set conceallevel=1
let g:tex_conceal='abdmg'
let g:vimtex_compiler_latexmk = {'callback' : 0}
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_new_list_item_indent = 0
let g:vimtex_compiler_enabled = 0

if has('nvim')
  let g:vimtex_compiler_progname = 'nvr'
endif

let g:vim_markdown_preview_hotkey='<Leader>m'

if executable('grip')
  let vim_markdown_preview_toggle=1
  let vim_markdown_preview_github=1
else
  let vim_markdown_preview_toggle=0
  let vim_markdown_preview_pandoc=1
endif

let vim_markdown_preview_temp_file=1

" Airline
let g:airline_theme='nord'
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

function! MyLineNumber()
  return substitute(line('.'), '\d\@<=\(\(\d\{3\}\)\+\)$', ',&', 'g'). ' | '.
    \    substitute(line('$'), '\d\@<=\(\(\d\{3\}\)\+\)$', ',&', 'g')
endfunction

if &rtp =~ 'vim-airline'
  call airline#parts#define('linenr',
    \ {'function': 'MyLineNumber', 'accents': 'bold'})
  let g:airline_section_z = airline#section#create(['%3p%%: ', 'linenr', ':%3v'])
endif

" Polyglot
let g:polyglot_disabled = ['python', 'go', 'markdown', 'latex']

" FZF
let g:fzf_command_prefix = 'Fzf'
let g:fzf_layout = { 'up': '~35%' }
let g:fzf_action = {
      \ 'ctrl-h': 'split',
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

if isdirectory('.git')
  noremap <C-T> :FzfGitFiles --cached --others --exclude-standard<CR>
else
  noremap <C-T> :FzfFiles <CR>
endif

noremap <C-H> :FzfHelptags <CR>
nnoremap <C-B> :FzfBuffers<Cr>
nnoremap <C-F> :FzfAg <CR>
nnoremap <C-P> :FzfBLines<Cr>
" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options =
 \ '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
nnoremap <Leader>g :FzfBCommits<Cr>
nnoremap <Leader>h :FzfHistory<Cr>
nnoremap <Leader>t :Colors<Cr>
imap <C-X><C-F> <plug>(fzf-complete-path)
imap <C-X><C-J> <plug>(fzf-complete-file-ag)
imap <C-X><C-L> <plug>(fzf-complete-line)
" Dictionary completion
imap <expr> <C-X><C-K> fzf#vim#complete('cat /usr/share/dict/words')

" Toggle preview with '?' when searching w/ :FzfFiles or :FzfGitFiles
command! -bang -nargs=? -complete=dir FzfFiles
  \ call fzf#vim#files(
  \ <q-args>,
  \   <bang>0 ? fzf#vim#with_preview('up:35%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \ <bang>0)

command! -bang -nargs=? FzfGitFiles
  \ call fzf#vim#gitfiles(
  \ <q-args>,
  \   <bang>0 ? fzf#vim#with_preview('up:35%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \ <bang>0)

command! -bang Colors
  \ call fzf#vim#colors({'left': '15%', 'options': '--reverse --margin 5%,0'},
  \ <bang>0)

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

" vim fugitives
noremap <Leader>ga :Gwrite<CR>
noremap <Leader>gc :Gcommit<CR>
noremap <Leader>gp :Gpush<CR>
noremap <Leader>gl :Gpull<CR>
noremap <Leader>gst :Gstatus<CR>
noremap <Leader>gd :Gvdiff<CR>
noremap gdh :diffget //2<CR>
noremap gdl :diffget //3<CR>

" vim-go
let g:go_highlight_fields = 1
let g:go_fmt_fail_silently = 1
let g:go_def_mapping_enabled = 0

au FileType go nmap <F2> <Plug>(go-run)
au FileType go nmap <F3> <Plug>(go-doc)
au FileType go nmap <F4> <Plug>(go-info)
au FileType go nmap <F5> <Plug>(go-def)
au FileType go nmap <Leader>db <Plug>(go-doc-browser)
au FileType go nmap <Leader>r <Plug>(go-rename)
au FileType go nmap <Leader>t <Plug>(go-test)

" ALE (Asynchronous Lint Engine)
let g:ale_set_quickfix = 1
let g:ale_lint_delay = 500
let g:ale_lint_on_text_changed = 'normal'
let g:ale_linters = {
    \   'javascript': ['eslint'],
    \   'typescript': ['tslint'],
    \   'c': ['clang-format'],
    \   'cpp': ['clang-format'],
    \}
let g:ale_fixers = {
    \   'javascript': ['eslint'],
    \   'typescript': ['tslint'],
    \   'python': ['autopep8'],
    \   'go': ['go build'],
    \   'c': ['clang-format'],
    \   'cpp': ['clang-format'],
    \}
let g:ale_sign_error = 'A✗'
let g:ale_sign_warning = 'A▲'
let g:airline#extensions#ale#enabled = 1
nnoremap <silent> <Leader>at :ALEToggle<CR>
nnoremap <silent> <F12> :ALEFix<CR>

" YCM
let g:ycm_max_diagnostics_to_display = 1000
let g:ycm_filetype_blacklist = {}
let g:ycm_min_num_of_chars_for_completion = 1
let g:ycm_global_ycm_extra_conf = $DOTFILES.'vim/.ycm_extra_conf.py'
let g:ycm_confirm_extra_conf = 0
let g:ycm_path_to_python_interpreter =
  \ '/usr/local/opt/python/libexec/bin/python'
let g:ycm_python_binary_path= 'python'
let g:ycm_complete_in_comments=1
let g:ycm_autoclose_preview_window_after_completion=0
let g:ycm_autoclose_preview_window_after_insertion=1
let g:ycm_error_symbol='Y✗'
let g:ycm_warning_symbol='Y▲'
let g:ycm_complete_in_comments = 1
let g:ycm_collect_identifiers_from_comments_and_strings = 1
let g:ycm_collect_identifiers_from_tags_files = 1

if !exists('g:ycm_semantic_triggers')
  let g:ycm_semantic_triggers = {}
endif
let g:ycm_semantic_triggers.tex = g:vimtex#re#youcompleteme

au FileType c,cpp,javascript,python nmap <F2> :YcmForceCompileAndDiagnostics<CR>
au FileType c,cpp,javascript,python nmap <F3> :YcmCompleter GetDoc<CR>
au FileType c,cpp,javascript,python nmap <F4> :YcmCompleter GetType<CR>
au FileType c,cpp,javascript,python nmap <F5> :YcmCompleter GoTo<CR>

" UltiSnips
let g:UltiSnipsSnippetDirectories=[$HOME."/.config/nvim/snips"]
let g:UltiSnipsExpandTrigger="<C-L>"
let g:UltiSnipsJumpForwardTrigger="<C-J>"
let g:UltiSnipsJumpBackwardTrigger="<C-K>"
let g:snips_author = 'Frank Roeder'
let g:ultisnips_javascript = {
      \ 'keyword-spacing': 'always',
      \ 'semi': 'never',
      \ 'space-before-function-paren': 'always',
      \ }
