let g:fzf_command_prefix = 'Fzf'
let g:fzf_layout = { 'up': '~35%' }
let g:fzf_action = {
      \ 'ctrl-s': 'split',
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

let g:fzf_history_dir = expand("$HOME/.local/share/fzf-history")

if isdirectory('.git')
  noremap <C-T> :FzfGitFiles --cached --others --exclude-standard<CR>
else
  noremap <C-T> :FzfFiles <CR>
endif

if executable("rg")
	command! -bang -nargs=* Rg
		\ call fzf#vim#grep(
		\   'rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>), 1,
		\   fzf#vim#with_preview(), <bang>0)
  nnoremap <C-F> :FzfRg <CR>
else
  nnoremap <C-F> :FzfLines <CR>
endif

nnoremap <C-P> :FzfBLines<Cr>

" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options =
 \ '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
nnoremap <Leader>g :FzfBCommits<Cr>


" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1
nnoremap <C-B> :Buffers<Cr>

noremap <C-H> :FzfHelptags <CR>
nnoremap <Leader>h :FzfHistory<Cr>
nnoremap <Leader>t :Colors<Cr>
nnoremap <Leader>: :Commands<Cr>
nnoremap <Leader>m :Maps<Cr>
nnoremap <Leader>k :Marks<Cr>
nnoremap <Leader>us :FzfSnippets<Cr>

imap <C-X><C-F> <plug>(fzf-complete-path)
imap <C-X><C-J> <plug>(fzf-complete-file-ag)
imap <C-X><C-L> <plug>(fzf-complete-line)

" Dictionary completion
imap <expr> <C-X><C-K> fzf#vim#complete('cat /usr/share/dict/words')

lua << EOF
	-- Toggle preview with '?' when searching w/ :FzfFiles or :FzfGitFiles
  vim.api.nvim_create_user_command(
		"FzfFiles",
		"call fzf#vim#files( <q-args>, <bang>0 ? fzf#vim#with_preview('up:35%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)",
		{ nargs = '*', complete = 'dir' }
	)
  vim.api.nvim_create_user_command(
    "FzfGitFiles",
    "call fzf#vim#gitfiles(<q-args>, <bang>0 ? fzf#vim#with_preview('up:35%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)",
		{ nargs = '*' }
  )
  vim.api.nvim_create_user_command("Colors", "call fzf#vim#colors({'window': { 'width': 0.3, 'height': 0.6 } }, <bang>0)", {})
  vim.api.nvim_create_user_command("Buffers", "call fzf#vim#buffers({'window': { 'width': 0.6, 'height': 0.6 } }, <bang>0)", {})
  vim.api.nvim_create_user_command("Commands", "call fzf#vim#commands({'window': { 'width': 0.9, 'height': 0.6 } }, <bang>0)", {})
  vim.api.nvim_create_user_command("Maps", "call fzf#vim#maps('', {'window': { 'width': 0.9, 'height': 0.6 } },  <bang>0)", {})
  vim.api.nvim_create_user_command("Marks", "call fzf#vim#marks({'window': { 'width': 0.9, 'height': 0.6 } }, <bang>0)", {})
EOF
