function! StripTrailingWhitespaces()
  if !&binary && &filetype != 'diff'
    " last cursor and search position
    let _s=@/
    let l = line(".")
    let c = col(".")
    %s/\s\+$//e
    let @/=_s
    call cursor(l, c)
  endif
endfunction

" Rainbow
let g:rainbow_active = 1

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_update_on_bufenter=0

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
