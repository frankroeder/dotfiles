let g:vista_sidebar_width = 35
let g:vista_echo_cursor_strategy='echo'
let g:vista_close_on_fzf_select=1

let g:vista_default_executive = 'nvim_lsp'

noremap <Leader>v :Vista!!<CR>
noremap <Leader>p :Vista finder<CR>

augroup VistaMapping
  autocmd!
  autocmd FileType vista,vista_kind nnoremap <buffer> <silent> / :<c-u>call vista#finder#fzf#Run()<CR>
augroup END
