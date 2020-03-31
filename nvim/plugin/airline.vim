let g:airline_theme='onedark'
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1
let g:airline#extensions#whitespace#enabled = 0

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
