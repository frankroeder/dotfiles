set conceallevel=0
if executable('jq')
  " Format JSON with jq
  nnoremap <silent> <Leader>fj :%!jq '.'<CR>
endif
