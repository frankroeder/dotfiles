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

" language support
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries', 'for': 'go' }
Plug 'godlygeek/tabular', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', {'depends': 'godlygeek/tabular', 'for': 'markdown'}
Plug 'JamshedVesuna/vim-markdown-preview', { 'for': 'markdown' }
Plug 'lervag/vim-latex', { 'for': 'tex' }
Plug 'bassstring/apple-swift'

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
set signcolumn=yes
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
set autoindent
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
set t_Co=256                " Enable full-color support

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

" Treat given characters as a word boundary
set iskeyword-=.
set iskeyword-=#

let mapleader=","

" Return to last edit position when opening files
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") && &filetype != "gitcommit" |
  \   exe "normal! g`\"" |
  \ endif

" Set spell in certain cases
autocmd FileType gitcommit setl spell textwidth=72 | startinsert

autocmd FileType markdown,tex,text set complete+=kspell,k/usr/share/dict/words

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
  autocmd BufWritePost init.vim source % | :AirlineRefresh
augroup END

" Make crontab happy
autocmd filetype crontab setlocal nobackup nowritebackup

"Incrementing and decrementing alphabetical characters
set nrformats+=alpha


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

" spell check
map <silent> <F6> :setlocal spell! spelllang=en<CR>
map <silent> <F7> :setlocal spell! spelllang=de<CR>

" Spell error: pick the first result
nnoremap <Leader>z z=1<CR><CR>

" Fix spelling mistakes on the fly
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

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_update_on_bufenter=0

" TeX
set conceallevel=2
autocmd FileType tex set iskeyword+=:,-
let g:tex_conceal ='abdmg'
let g:tex_flavor = "latex"
let g:vimtex_view_method='skim'
let g:vimtex_view_general_viewer
      \ = '/Applications/Skim.app/Contents/SharedSupport/displayline'
let g:vimtex_view_general_options = '-r @line @pdf @tex'
let g:vimtex_quickfix_mode=0
let g:vimtex_compiler_latexmk = {'callback' : 0}
let g:vimtex_compiler_enabled = 0
let g:vimtex_toc_config = {
      \ 'split_pos': 'full',
      \ 'layer_status': {'label': 0}
      \}

augroup tex
  au FileType tex nmap <F2> :VimtexTocOpen <CR>
  au FileType tex nmap <F3> :VimtexInfo <CR>
  au FileType tex nmap <F4> :VimtexErrors <CR>
  au FileType tex nmap gd :VimtexDocPackage <CR>
augroup END

if has('nvim')
  let g:vimtex_compiler_progname = 'nvr'
endif

" Markdown
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_new_list_item_indent = 0
let g:vim_markdown_fenced_languages = ['html', 'css', 'js=javascript',
      \ 'c++=cpp', 'c', 'go', 'viml=vim', 'bash=sh', 'python']
let g:vim_markdown_strikethrough = 1

augroup markdown
  au FileType markdown nmap <F2> :Toct <CR>
  au FileType markdown nmap <F3> :HeaderIncrease <CR>
  au FileType markdown nmap <F4> :HeaderDecrease <CR>
  au FileType markdown nmap <F5> :TableFormat <CR>
augroup END

" Markdown Preview
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
let g:airline_theme='onedark'
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1
let g:airline#extensions#coc#enabled = 1

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

let g:airline#extensions#whitespace#enabled = 0

" FZF
let g:fzf_command_prefix = 'Fzf'
let g:fzf_layout = { 'up': '~35%' }
let g:fzf_action = {
      \ 'ctrl-t': 'tab split',
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
nnoremap <C-B> :Buffers<Cr>
nnoremap <C-F> :FzfAg <CR>
nnoremap <C-P> :FzfBLines<Cr>
" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options =
 \ '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
nnoremap <Leader>g :FzfBCommits<Cr>
nnoremap <Leader>h :FzfHistory<Cr>
nnoremap <Leader>t :Colors<Cr>
nnoremap <Leader>: :Commands<Cr>
nnoremap <Leader>m :Maps<Cr>
nnoremap <Leader>k :Marks<Cr>
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
      \ call fzf#vim#colors({'window': 'call CreateCenteredFloatingWindow()'},
      \ <bang>0)

command! -bang Buffers
      \ call fzf#vim#buffers({'window': 'call CreateCenteredFloatingWindow()'},
      \ <bang>0)

command! -bang Commands
      \ call fzf#vim#commands({'window': 'call CreateCenteredFloatingWindow()'},
      \ <bang>0)

command! -bang Maps
      \ call fzf#vim#maps('', {'window': 'call CreateCenteredFloatingWindow()'},
      \ <bang>0)

command! -bang Marks
      \ call fzf#vim#marks({'window': 'call CreateCenteredFloatingWindow()'},
      \ <bang>0)

function! CreateCenteredFloatingWindow()
  let width = min([&columns - 4, max([80, &columns - 20])])
  let height = min([&lines - 4, max([20, &lines - 10])])
  let top = ((&lines - height) / 2) - 1
  let left = (&columns - width) / 2
  let opts = {'relative': 'editor', 'row': top, 'col': left, 'width': width,
        \'height': height, 'style': 'minimal'}
  let top = "╭" . repeat("─", width - 2) . "╮"
  let mid = "│" . repeat(" ", width - 2) . "│"
  let bot = "╰" . repeat("─", width - 2) . "╯"
  let lines = [top] + repeat([mid], height - 2) + [bot]
  let s:buf = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_lines(s:buf, 0, -1, v:true, lines)
  call nvim_open_win(s:buf, v:true, opts)
  set winhl=Normal:Floating
  let opts.row += 1
  let opts.height -= 2
  let opts.col += 2
  let opts.width -= 4
  call nvim_open_win(nvim_create_buf(v:false, v:true), v:true, opts)
  au BufWipeout <buffer> exe 'bw '.s:buf
endfunction

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
noremap <Leader>gb :Gbrowse<CR>
noremap <Leader>gl :Gpull<CR>
noremap <Leader>gst :Gstatus<CR>
noremap <Leader>gd :Gvdiff<CR>
noremap gdh :diffget //2<CR>
noremap gdl :diffget //3<CR>

" vim-go
let g:go_highlight_fields = 1
let g:go_fmt_fail_silently = 1
let g:go_def_mapping_enabled = 0

augroup go
  au FileType go nmap <F2> <Plug>(go-run)
  au FileType go nmap <F3> <Plug>(go-doc)
  au FileType go nmap <F4> <Plug>(go-info)
  au FileType go nmap gd <Plug>(go-def)
  au FileType go nmap <Leader>db <Plug>(go-doc-browser)
  au FileType go nmap <Leader>r <Plug>(go-rename)
  au FileType go nmap <Leader>t <Plug>(go-test)
augroup END

" coc

" nord-vim like colors
hi! CocErrorSign  ctermfg=Red guifg=#be5046
hi! CocWarningSign  ctermfg=Brown guifg=#d19a66
hi! CocInfoSign  ctermfg=Yellow guifg=#e5c07b

let g:coc_global_extensions = [
      \'coc-tsserver', 'coc-python','coc-css', 'coc-snippets', 'coc-json',
      \'coc-html', 'coc-vimtex'
      \]
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <C-space> coc#refresh()

inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Use <tab> for select selections ranges, needs server support, like: coc-tsserver, coc-python
nmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <S-TAB> <Plug>(coc-range-select-backword)

nmap <silent> <F2> <Plug>(coc-implementation)
nmap <silent> <F3> <Plug>(coc-type-definition)
nmap <silent> <F4> <Plug>(coc-references)
nmap <silent> gd <Plug>(coc-definition)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

nmap <leader>rn <Plug>(coc-rename)
nmap <silent> gp <Plug>(coc-diagnostic-prev)
nmap <silent> gn <Plug>(coc-diagnostic-next)
command! -nargs=0 Format :call CocAction('format')
nnoremap <silent> <F12> :call CocAction('format') <CR>
command! -nargs=? Lint :call CocAction('runCommand', 'python.enableLinting')
command! -nargs=? Fold :call CocAction('fold', <f-args>)
command! -nargs=0 OR :call CocAction('runCommand', 'editor.action.organizeImport')
nnoremap <silent> <leader>cR  :<C-u>CocRestart<CR>

" coc-snippets
" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)
" Use <C-j> for both expand and jump (make expand higher priority.)
imap <C-j> <Plug>(coc-snippets-expand-jump)
