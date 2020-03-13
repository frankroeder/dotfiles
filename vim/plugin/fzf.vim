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
