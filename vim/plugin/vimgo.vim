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
