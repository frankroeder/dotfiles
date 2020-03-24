let g:airline_theme='onedark'
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1
let g:airline#extensions#whitespace#enabled = 0

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

function! MyLineNumber()
  return substitute(line('.'), '\d\@<=\(\(\d\{3\}\)\+\)$', ',&', 'g'). ' | '.
        \ substitute(line('$'), '\d\@<=\(\(\d\{3\}\)\+\)$', ',&', 'g')
endfunction

if &rtp =~ 'vim-airline'
  call airline#parts#define('linenr',
        \ {'function': 'MyLineNumber', 'accents': 'bold'})
  let g:airline_section_z = airline#section#create(['%3p%%: ', 'linenr', ':%3v'])
endif
