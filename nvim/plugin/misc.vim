" float-preview
let g:float_preview#docked = 1
function! DisableExtras()
  call nvim_win_set_option(g:float_preview#win, 'number', v:false)
  call nvim_win_set_option(g:float_preview#win, 'relativenumber', v:false)
  call nvim_win_set_option(g:float_preview#win, 'cursorline', v:false)
  call nvim_win_set_option(g:float_preview#win, 'conceallevel', 2)
endfunction

autocmd User FloatPreviewWinOpen call DisableExtras()

" echodoc
let g:echodoc_enable_at_startup = 1
let g:echodoc#type = 'signature'

" Rainbow
let g:rainbow_active = 1

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_update_on_bufenter=0
