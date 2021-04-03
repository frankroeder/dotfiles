" float-preview
let g:float_preview#docked = 1

function! DisableExtras()
  call nvim_win_set_option(g:float_preview#win, 'number', v:false)
  call nvim_win_set_option(g:float_preview#win, 'relativenumber', v:false)
  call nvim_win_set_option(g:float_preview#win, 'cursorline', v:false)
  call nvim_win_set_option(g:float_preview#win, 'conceallevel', 3)
endfunction

augroup float_preview
  autocmd!
  autocmd User FloatPreviewWinOpen call DisableExtras()
augroup END

" echodoc
let g:echodoc_enable_at_startup = 1
let g:echodoc#type = 'signature'

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_update_on_bufenter=0

" Neopairs
let g:neopairs#enable=1
