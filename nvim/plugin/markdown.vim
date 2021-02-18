let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_new_list_item_indent = 0
let g:vim_markdown_fenced_languages = ['html', 'css', 'js=javascript',
      \ 'c++=cpp', 'c', 'go', 'viml=vim', 'bash=sh', 'python']
let g:vim_markdown_strikethrough = 1

" Markdown Preview
let g:vim_markdown_preview_hotkey='<Leader>mp'

if executable('grip')
  let vim_markdown_preview_toggle=1
  let vim_markdown_preview_github=1
else
  let vim_markdown_preview_toggle=0
  let vim_markdown_preview_pandoc=1
endif

let vim_markdown_preview_temp_file=1

augroup markdown
  au Filetype markdown nmap <buffer> <F2> :Toct <CR>
  au Filetype markdown nmap <buffer> <F3> :HeaderIncrease <CR>
  au Filetype markdown nmap <buffer> <F4> :HeaderDecrease <CR>
  au Filetype markdown nmap <buffer> <F5> :TableFormat <CR>
augroup END
